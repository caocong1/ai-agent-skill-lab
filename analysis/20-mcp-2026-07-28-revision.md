# MCP 规范 2026-07-28 修订分析

> 分析版本：1.0 ｜ 最后更新：2026-08-23 ｜ 来源：Model Context Protocol Specification 2026-07-28（发布 2026-07-28，抓取 2026-08-23，上一版 2025-11-25）｜ 快照：`raw/docs/mcp-2026-07-28-specification.md`

本仓库此前对 MCP 的分析来自 `analysis/02-agent-framework-patterns.md` 里的 TypeScript SDK 部分，视角是"如何写一个 MCP server"。这一版规范修订的量级不同：它**改变了 MCP 是什么形状的协议**。2025-11-25 之前的 MCP 是有会话、有握手、服务端可以反向发起请求的**双工有状态协议**；2026-07-28 之后它是**无状态、单向请求-响应**的协议。任何按旧形状写的 server 与 client 都要重新审视，而不是打个补丁。

更值得本仓库注意的是，这次修订在两个地方与本仓库正在收敛的判断**独立撞车**：一是把"流可恢复性"明确划为非目标（与 `analysis/01-pi-source-analysis.md` 记录的 Pi harness 非目标清单一致）；二是第一次由**协议层**写下 KV cache 经济学——`tools/list` 应确定性排序，理由直接写成"提高 LLM prompt cache 命中率"。

## 核心抽象

- **无状态化 = 把隐式会话状态外置成显式句柄**。删除 `initialize` / `notifications/initialized` 与 `Mcp-Session-Id` 之后，协议不再替你保存任何跨调用状态。需要状态的服务端必须**自己铸造句柄，并让它作为普通 tool 参数往返**。这与 Pi 的 registers、DeepSeek Harness 的 event-sourced session log 是同一条原则的三种体现：状态要么是显式数据，要么就不存在。
- **MRTR 把"服务端反向调用"翻转成"客户端重试并补料"**。旧模型是 server 反过来调 client（`roots/list` / `sampling/createMessage` / `elicitation/create`），需要一条双向通道。新模型是 server 返回 `InputRequiredResult`（`resultType: "input_required"`，`inputRequests` 说明还缺什么），client **重发原请求**并附上 `inputResponses`。形状上等同于 HTTP 的 `401` + `WWW-Authenticate` → 带凭据重试。
- **`resultType` 是一个闭合的判别式联合**，且为老实现定义了默认值（省略即 `"complete"`）。这与 `analysis/18-deepseek-harness.md` 的 `ApprovalOutcome` 四元组是同一种设计动作：把"结果的种类"变成显式且穷尽的枚举，而不是靠字段是否存在去猜。
- **缓存进入协议契约**。`CacheableResult` 把 `ttlMs`（新鲜度提示）与 `cacheScope`（`"public"` / `"private"`）设成 list/read 类结果的**必填字段**，与既有的 `listChanged` 通知互补：通知负责"变了告诉我"，TTL 负责"没通知时我能放心用多久"。
- **弃用变成有政策的工程动作**。新的特性生命周期政策定义 Active / Deprecated / Removed 三态、**最短 12 个月**弃用窗口和一份已弃用特性登记表。Roots / Sampling / Logging 三个特性同时进入 Deprecated。
- **命名空间分配是兼容性工具**。错误码 `-32000`~`-32019` 留给实现自定义（既有用法既往不咎），`-32020`~`-32099` 保留给规范；`_meta` 的键统一走 `io.modelcontextprotocol/*` 前缀。两者是同一个手法：先划保留区，再迁移。

## 重要模式

### 反向调用被"补料重试"取代，代价是幂等性变成硬要求

MRTR 的优点很清楚：不需要双工通道，请求可以被任意路由、负载均衡、重放，client 端不需要实现 server 侧发起的 RPC。但它有一个规范文本没有点破、却是直接后果的推论（**下面这段是推论，不是规范原文**）：

一次逻辑操作现在可能对应**多次真实请求**——第一次拿到 `input_required`，第二次带 `inputResponses` 重发。如果 tool 的实现在返回 `input_required` 之前已经产生了副作用，这个副作用会随重试被执行两次。所以在 MRTR 下：

- 需要输入的 tool，**必须在产生任何副作用之前**返回 `input_required`；
- 或者副作用必须幂等，用服务端铸造的句柄做去重键。

这正好是 `analysis/01-pi-source-analysis.md` 里 effect sandwich（先提交意图与预铸 id，再做不确定的副作用，最后提交结算）要解决的同一个问题。协议把重试变成一等公民，就把幂等性从"最佳实践"提升成了"正确性前提"。

### "流可恢复性"被两套独立系统同时划为非目标

规范删除了 `Last-Event-ID` 与 SSE event id：响应流一断，在途请求就丢，客户端 **MUST** 用**新的 request id** 发起一个新请求。Pi 的 harness 文档在它的显式非目标清单里写着同一条（stream resumption 不做）。

两个互不相干的设计做出同一个取舍，说明这是个有普遍性的判断：**流恢复的实现成本（服务端要缓冲、要记 offset、要处理重复投递）高于它的收益，因为上层总归需要一个"重做整个请求"的路径来兜底**。与其做一个只在部分故障下生效的恢复机制，不如把"重发"做成唯一路径。真正需要跨断连存活的长任务，交给 tasks 扩展的轮询模型，而不是让传输层背这个责任。

对本仓库的直接含义：`skills/design-ai-agent` 里"长任务如何跨中断"的答案，应该是**可轮询的任务句柄**，不是"可恢复的流"。

### 协议层第一次写下 KV cache 经济学

`tools/list` **SHOULD** 返回确定性顺序，理由分两半：便于客户端缓存，以及**提高 LLM prompt cache 命中率**。后半句是关键——工具列表会被渲染进系统提示的前缀，顺序一抖动，整个后缀的 prompt cache 就全部失效。

这条把一个此前只存在于 harness 实现经验里的东西写成了规范：**工具定义是 prompt 前缀的一部分，前缀的稳定性有直接的钱和延迟代价**。`analysis/18-deepseek-harness.md` 里 DeepSeek Harness 的每个包 README 都必须写 `#### KV Cache effect` 一节，是同一个认知的另一种制度化。本仓库此前的 `design-agent-tools` 只讲工具的语义设计（命名、参数、返回体积），没有讲**工具集合本身的排列稳定性**，这是一个实打实的缺口。

延伸推论（非规范原文）：同样的道理适用于任何进入前缀的动态内容——工具集合的顺序、skill 列表、环境快照、日期时间戳。凡是每轮都可能变的东西，要么固定顺序、要么挪到前缀之后。

### 缓存作用域同时是一条安全边界

`cacheScope` 的两个取值不只是性能开关：`"private"` 的作用是**禁止共享中间层缓存该响应**。当 `resources/read` 返回的是按用户鉴权的内容时，标错 scope 等价于把 A 用户的资源缓存给 B 用户。这与 HTTP `Cache-Control: private` 是同一个陷阱，只是现在它出现在 agent 的资源读取路径上。

### Roots / Sampling / Logging 的弃用是"harness 假设过期"的协议级实例

`analysis/19-anthropic-harness-design-long-running-apps.md` 的核心元规则是：harness 里每个组件都编码了一条"模型/环境自己做不到什么"的假设，而假设有保质期。这三个特性的弃用理由恰好逐条对上：

- **Sampling** 的前提是"server 没有模型，client 有"。现在官方建议是**直接对接 LLM 供应商 API**——这个前提消失了。
- **Roots** 的前提是"没有别的办法把工作区告诉 server"。现在建议用 tool 参数、resource URI 或服务端配置——通用手段已经够用。
- **Logging** 的前提是"没有别的可观测通道"。现在建议 stdio 写 `stderr` 或用 OpenTelemetry——生态补上了。

三条都不是被更好的设计取代，而是被**周边能力变强**淘汰的。这是"假设过期"最典型的形态，也是为什么这份清单值得定期重扫，而不是等到 breaking change 才被动响应。

### 弃用政策本身是一个可复用的契约工程模式

三态（Active / Deprecated / Removed）+ 最短 12 个月窗口 + 一份**集中登记表**，比"在 changelog 里写一句 deprecated"强得多，因为它让下游可以**程序化地查询**"我用的东西还剩多久"。SemVer 只告诉你"这次是不是 breaking"，弃用登记表告诉你"下次哪里会 breaking"。

本仓库自己的 `build-ai-agents` 契约（mode / deliverable / reference 三类被 SemVer 保护的东西）目前只有 MAJOR 规则，没有弃用窗口概念。这是一个可以直接借鉴的缺口。

### 安全面的收紧集中在 OAuth 的"换服务器"攻击面

- 授权响应 SHOULD 带 `iss`（RFC 9207），客户端 **MUST** 在兑换授权码前校验它与已记录 issuer 一致——防的是授权服务器混淆（mix-up）攻击。
- 客户端凭据 **MUST** 以 issuer 为键持久化，**MUST NOT** 跨授权服务器复用，服务器变更时 MUST 重新注册。
- DCR 时必须指定 `application_type`，避免 OIDC 重定向 URI 冲突。
- DCR（RFC 7591）整体被弃用，改用 Client ID Metadata Documents。

共同主题是：**凭据的身份边界必须显式绑定到签发方**，不能靠"我记得我注册过"。

## 工程启发

- **需要跨调用状态时，铸造显式句柄并把它当普通参数传**，不要依赖传输层或协议层替你记住任何东西。句柄的生命周期、鉴权和回收都是你自己的责任，要一起设计。
- **让工具列表的顺序确定**，并把"什么东西会进入 prompt 前缀"当作一个显式清单来维护。前缀稳定性是成本项，不是洁癖。
- **要输入就先返回"缺什么"，别在中途反向问**。返回结构化的 `inputRequests` 让调用方补料重试，比在工具内部阻塞等待更容易路由、重放和测试。
- **重试是一等公民 ⇒ 副作用必须在补料之后**，或者用去重键做幂等。任何"先写后问"的工具在 MRTR 下都是错的。
- **给结果种类一个闭合枚举，并为缺省值定义语义**（省略即 `"complete"`）。这样老实现不会因为字段缺失被判为异常。
- **缓存元数据要和数据一起返回**：TTL 回答"能用多久"，scope 回答"谁能看到"。二者缺一，缓存要么无效要么越权。
- **长任务用可轮询句柄，不用可恢复流**。断连恢复的正确抽象是"再查一次任务状态"，不是"从 offset 续传"。
- **给自己的契约配一套弃用政策**：三态 + 最短窗口 + 集中登记表。没有登记表的弃用等于没有弃用。
- **保留区先划、再迁移**：错误码、`_meta` 键、扩展命名空间都用同一手法。给第三方一块明确的自留地，规范才有空间演进。
- **周期性重扫"这个特性还有没有理由存在"**。Roots / Sampling / Logging 的下场说明：能力边界一移动，为旧边界设计的特性就会整块失效。

## 适用场景

- 正在写或维护 **MCP server / client**，尤其是已经依赖 `initialize`、`Mcp-Session-Id`、`roots/list`、`sampling/createMessage`、`elicitation/create`、`resources/subscribe`、SSE 恢复中任何一项的实现——这些都需要迁移方案。
- 设计**任何** agent ↔ 工具服务的自定义协议：无状态 + 补料重试 + 闭合 resultType 是一组可直接照搬的取舍。
- 关心 **prompt cache 成本**的场景：确定性工具排序是最低成本、最高杠杆的一条。
- **不适合**：只在单进程内调用本地函数、没有网络与跨进程边界的 agent，本文大部分取舍是为分布式与可重放场景付的代价。

## 注意

- 本篇基于 changelog 与规范页面的转述，**未逐条核对 schema.json 与各 SDK 的实现进度**。规范发布与 SDK 落地之间通常有滞后，迁移前要单独确认所用 SDK 的版本支持面。
- 弃用 ≠ 移除。Roots / Sampling / Logging 在**至少 12 个月**窗口内仍然完全可用；对存量实现，正确动作是"不新增依赖 + 排期迁移"，而不是立刻重写。
- **无状态化把负担推给了服务端实现者**。协议不再管会话，句柄的铸造、鉴权、过期与 GC 全部变成 tool 参数层的自建设施——这部分复杂度没有消失，只是换了位置。
- `x-mcp-header`（从 tool 参数注入自定义 HTTP 头）是一个需要在评审里单独看的面：**tool 参数通常是模型可控的**，让模型可控的值落到 HTTP 头上是经典的注入形状。规范只描述了机制，没有给出白名单要求（**这条是本仓库的评审判断，不是规范结论**）。
- MRTR 下"一次逻辑操作 = 多次请求"的幂等性要求是推论，规范文本未直接写出；实现时应当把它当作自己的不变量来测。
- 移除流恢复对**已经**依赖长连接续传的实现是实质性的能力回退，需要评估是否改用 tasks 扩展。tasks 现在是扩展而非核心，意味着服务端可能根本没实现它。

## 对最终 skill 的影响

- `skills/build-mcp-capabilities/SKILL.md`：按 2026-07-28 重写协议基线——无状态核心（无 `initialize` / 无 `Mcp-Session-Id`）、必须实现 `server/discover`、MRTR 取代反向请求、必填 `resultType`、`subscriptions/listen` 取代 GET 端点与 `resources/subscribe`、tasks 转为 `io.modelcontextprotocol/tasks` 扩展并改为轮询、`CacheableResult` 的 `ttlMs` / `cacheScope`、`tools/list` 确定性排序、`Mcp-Method` / `Mcp-Name` 请求头、错误码分区与 `-32002`→`-32602`、Roots / Sampling / Logging 弃用与迁移路径。
- `skills/design-agent-tools/SKILL.md`：新增"工具集合的排列稳定性影响 prompt cache"、"跨调用状态用显式句柄参数"、"需要输入时返回结构化缺口而非阻塞反问"、"重试语义下副作用必须后置或幂等"。
- `skills/secure-ai-agents/SKILL.md`：新增 OAuth `iss` 校验（RFC 9207）、凭据按 issuer 绑定且禁止跨授权服务器复用、DCR 弃用与 `application_type`、`cacheScope: private` 作为越权缓存边界、`x-mcp-header` 的模型可控值注入面。
- `skills/design-ai-agent/SKILL.md`：新增"长任务用可轮询句柄而非可恢复流"、"结果种类用闭合枚举并定义缺省语义"，以及"对外契约需要弃用政策（三态 + 最短窗口 + 登记表），不只是 SemVer"。
- `skills/review-ai-agents/SKILL.md`：审查面新增"是否新引入了已弃用的 MCP 特性"与"MRTR 下是否存在补料前副作用"。
- `skills/build-ai-agents/references/source-map.md`：登记本规范修订与快照路径。
- `analysis/07-overall-agent-analysis.md`：把"KV cache / prompt 前缀经济学"与"显式非目标清单"纳入跨来源共识矩阵。
