# Pi 源码分析

> 分析版本：1.1 ｜ 最后更新：2026-08-23 ｜ 来源：Pi（commit `a69bef78`，v0.84.x 线，详见 `analysis/SOURCE_INDEX.md`）
>
> 1.1 变更：新增 `## 持久化执行 harness`（基于 `packages/agent/docs/harness.md`，该文件由 `agent-harness.md` 重命名而来并大幅扩写）与 `## v0.78 → v0.84 增量`。原有章节基于 `4943c1d` 快照，核对后未失效。

Pi 是这批材料里最适合学习“编码 agent 本身如何组织”的项目。它不是只把模型 API 包一层，而是把 agent loop、工具执行、会话持久化、资源加载、skill 发现、扩展机制和 subagent 都拆成了相对清晰的层。

## 模块边界

Pi README 中把仓库拆成三层：

- `@earendil-works/pi-ai`: 多 provider LLM API 适配层。
- `@earendil-works/pi-agent-core`: agent runtime，负责 tool calling 和 state management。
- `@earendil-works/pi-coding-agent`: 面向编码场景的 CLI、tools、resource loader、skills、extensions。

这个拆分很值得复用：业务项目里不要直接让“聊天接口”同时承担模型、工具、权限、记忆、事件流、UI 和文件操作。更稳的划分是：

- model adapter: 只负责 provider 兼容和消息格式。
- agent runtime: 只负责循环、工具调用、停止条件、事件、错误语义。
- host integration: 负责项目文件、权限、用户确认、配置、命令和 UI。

## Agent loop

`packages/agent/src/agent-loop.ts` 是核心学习文件。它的关键设计是把“一轮用户输入”拆成外层 turn loop 和内层 tool loop。

关键点：

- 内部消息使用 `AgentMessage[]`，到 LLM 边界再转换为 provider 需要的消息格式。
- `transformContext()` 在每次模型调用前处理上下文，适合做压缩、裁剪、注入系统信息。
- `convertToLlm()` 隔离 provider 格式，避免工具层依赖具体模型供应商。
- 工具调用可以默认并行，工具或配置要求时再顺序执行。
- 工具参数先 schema 校验，再执行。
- `beforeToolCall` 可以阻断危险工具；`afterToolCall` 可以改写或补充结果。
- 工具结果按 assistant 中 tool call 的顺序返回，避免并发执行导致消息顺序混乱。
- 当一批工具结果都标记 `terminate:true` 时结束该批处理。
- agent loop 通过事件向外发出 `agent_start`、`turn_start`、`message_start/update/end`、`tool_execution_start/update/end`、`turn_end`、`agent_end`。

这里的核心经验：agent loop 必须是“事件化”和“边界清晰”的。否则后续接 UI、日志、审批、测试回放、成本统计时会很痛苦。

## Harness/session 层

`packages/agent/src/harness/agent-harness.ts` 是 loop 上面的宿主层。它负责：

- 会话持久化。
- runtime config。
- resource resolution。
- 运行时锁。
- extension mutation semantics。
- prompt、skill、compact、navigateTree 等结构性操作。

它区分了 harness config、turn snapshot、session、pending writes。这个区分非常重要：一次模型请求开始后，应使用稳定的 turn snapshot；中途更新配置不应该偷偷改变当前 provider request，而是影响下一轮。

另一个值得学习的点是“结构性操作需要 idle”。例如切换 prompt、加载 skill、压缩上下文、导航历史树，都不应该在 agent loop 正在运行时随便改会话结构。具体业务项目可以简化实现，但原则应该保留。

## Skills

Pi 的 skill 机制有两层：

- `packages/agent/src/harness/skills.ts`: 加载和格式化 skill 元数据。
- `packages/coding-agent/docs/skills.md`: 面向用户的 skill 规则和目录规范。

Pi 支持从多个位置加载 skill：

- 全局目录，如 `~/.pi/agent/skills`、`~/.agents/skills`。
- 项目目录，如 `.pi/skills`、`.agents/skills`。
- package、settings、CLI 指定目录。

Pi 的 skill 设计遵循 progressive disclosure：系统 prompt 先只给 skill 名称和描述，模型判断相关后再读取具体内容。对业务项目来说，这比“把所有操作指南塞进系统 prompt”更可控。

可复用原则：

- skill 名称保持短、稳定、hyphen-case。
- description 要说明触发场景，而不只是说明主题。
- 大段参考资料放到 `references/`，主 `SKILL.md` 只写工作流和入口。
- skill 中的可执行脚本必须被视为供应链风险，需要审查。

## Resource loader 与系统提示词

`packages/coding-agent/src/core/resource-loader.ts` 负责查找 `AGENTS.md`、`CLAUDE.md`、skills、prompt templates、themes、extensions。它会从 agentDir 和 cwd ancestors 读取上下文文件。

`packages/coding-agent/src/core/system-prompt.ts` 体现了一个很实际的细节：只有在读文件工具可用时，才把 skill metadata 注入系统提示词。这避免了模型知道“有 skill”，却没有能力读取 skill 内容。

可复用原则：

- 资源加载要有确定的优先级和覆盖规则。
- context 文件和 skill metadata 应该作为“能力声明”，不要代替真正的代码读取。
- prompt 里只注入当前工具能力能支撑的内容。

## Extensions 与权限

`permission-gate.ts` 展示了危险命令前的确认机制。它不是依赖模型“自觉安全”，而是在工具执行前的 hook 上硬拦截。

`dynamic-tools.ts` 展示了会话启动时和命令触发时动态注册工具。这适合多租户、权限差异、插件化工具集等业务场景。

可复用原则：

- 权限控制放在工具执行边界，不要只写在 prompt 里。
- 工具暴露可以动态化，但每次模型调用前需要明确 active tool set。
- 高风险工具必须支持 deny、approve、audit trail。

## Subagent

Pi 的 subagent 示例把子 agent 作为隔离进程运行，支持 single、parallel、chain。项目 agent definition 还需要信任或确认。

可复用原则：

- subagent 适合隔离上下文和工具权限，不适合简单任务。
- 并行 subagent 要求子任务互相独立，主 agent 只合成结果。
- 子 agent 输出应该是压缩后的事实与结论，而不是完整过程日志。
- 项目级 agent 定义要按不可信配置处理。

## 持久化执行 harness

`packages/agent/docs/harness.md` 是 1.0 快照之后新增/扩写的部分，也是 Pi 在本仓库所有来源里**独有**的一层：它不讨论 agent 怎么想，而讨论 **agent 的执行过程如何在进程崩溃后原样接上**。

### 三个存储，职责不重叠

- **entries**：一棵**只写一次**的树。已写入的条目不可修改，历史因此是可信的。
- **registers**：可变的、带命名空间的单元格。它承担"当前状态"，与不可变历史分离。
- **usage ledger**：只追加的用量账本。成本与 token 的会计独立于对话内容。

这套划分的价值在于**把"发生过什么"和"现在是什么"分开存**。多数 agent 实现只有一份可变的消息数组，于是"重放"和"当前态"互相污染。

### 持久化程序计数器

每一步结束后，`op.state/{operationId}` 会被**整体覆写为当前的完整状态**——不是增量、不是 diff。恢复时只读一个 register 然后 switch 到对应分支即可。

这是一个反直觉但正确的取舍：写入变大，换来的是**恢复逻辑没有重放语义**。不需要"从头重放 N 步"，因此也不会有"重放到一半状态不一致"的中间态。与事件溯源（`analysis/18-deepseek-harness.md` 的 session log）形成对照：DeepSeek 用投影从事件流推导当前态，Pi 用覆写直接存当前态。两者都对，区别是**谁承担推导成本**。

### Effect sandwich

对不确定的副作用，Pi 的模式是三明治：

1. **提交意图**——连同**预先铸好的输出 id** 一起写进不可变历史；
2. **执行不确定的副作用**；
3. **提交结算**。

预铸 id 是关键：崩溃后恢复时，可以用这个 id 去问外部系统"这件事做了没有"，而不需要猜。这正是 `analysis/20-mcp-2026-07-28-revision.md` 里 MRTR 重试语义所要求的幂等基础设施的具体实现。

### 按工具声明重放策略

每个工具声明 `replay: "never" | "safe"`。不可重放的工具在恢复时会得到一个**合成的 "interrupted" 结果**，从而**保住 call/result 的配对**——模型看到的消息序列仍然是良构的，只是内容变成"这次被中断了"。

这条很重要：多数实现在恢复时直接丢掉未完成的 tool call，导致模型看到一个悬空的 call，行为立刻发散。用一个合成结果占位，比丢弃更安全。

### Lanes

lane 是**共享条目树上的具名游标**。Slack 线程、subagent、并行任务各自持有一个 lane，读同一棵树的不同位置。它取代了"每个并发单元一份独立历史"的做法，因此不需要合并冲突。

### 显式非目标

harness 文档明确列出**不做**的事：exactly-once 外部副作用、流恢复、多写者、复制、可变写入历史、删除（除管理性的"精确重写"外）。

这份清单本身是一种工程表达。它让读者能在 5 分钟内判断"这个 harness 适不适合我"，而不是读完全部实现再发现缺了关键能力。**非目标清单应该和能力清单同等醒目**——这条已被 `analysis/20` 记录的 MCP "删除流恢复"独立佐证。

## v0.78 → v0.84 增量

1.0 快照（v0.75.3）之后到 v0.84.2 的窗口里，绝大多数是 TUI 与 provider 侧的功能，不触及已分析抽象。命中本仓库关注面的只有四条：

- **约束式工具采样**（v0.82.0）：工具可以声明 prefer / require 严格 JSON Schema 采样，或使用 Lark / regex 语法；模型能力元数据会**阻止向不支持的模型发出该请求**。这是"schema-first 工具"的下一步——schema 不只用于校验返回，还用于约束生成。关键设计是那条能力元数据闸门：能力不足时**提前失败**，而不是让模型生成非法输出再报错。
- **终止性工具批次**（v0.84.1）：扩展的 `tool_call` 处理器可以让一整批 all-terminating 的调用停下来，**不再多花一次模型调用**。与 `analysis/18-deepseek-harness.md` 的 `concludeTurn()` 是同一个原语：让工具层有能力直接结束当前轮，而不是把结束权全部留给模型。
- **可配置默认工具集**（v0.84.2）：启动时的内建工具可以全局或按项目配置。工具集合的组成变成配置项，而非硬编码——与 `analysis/20` 的"工具列表是 prompt 前缀"合起来看，工具集合的**内容与顺序都应该是可声明、可稳定的**。
- **`AGENTS.override.md`**（v0.84.0）：按目录**替换**（而非追加）上下文文件。上下文文件的作用域从"层层累加"扩展到"可被局部覆盖"，这对 monorepo 里子项目约定与根约定冲突的场景是必要的。

## 对最终 skill 的影响

最终 `build-ai-agents` skill 采用 Pi 的几个核心原则：

- 先判断 agent 形态，再选 loop/graph/workflow/MCP。
- 明确 model、tools、state、memory、approval、events 的边界。
- 工具必须 schema-first，错误必须能被模型理解和自我修复。
- 长任务必须有 step budget、token budget、cost budget 或 checkpoint。
- skill 本身也采用 progressive disclosure，把细节拆入 references。

1.1 追加：

- 长任务的恢复能力要按"持久化程序计数器 + 预铸 id 的 effect sandwich + 按工具声明的重放策略"三件套设计，而不是靠重放消息数组。
- 恢复时对未完成的工具调用要合成中断结果，保住 call/result 配对。
- 对外发布的 harness / 框架要同时给出**非目标清单**。
- 工具的 schema 可以同时用于约束模型生成，且要有能力闸门在不支持时提前失败。
