# Anthropic Managed Agents 分析：把 agent 虚拟化成三个基础设施接口

> 分析版本：1.0 ｜ 最后更新：2026-10-25 ｜ 来源：Anthropic《Scaling Managed Agents: Decoupling the brain from the hands》（发布 2026-04-08，抓取 2026-10-25）｜ 快照：`raw/docs/anthropic-managed-agents.md`

这是本仓库第一篇把 harness 问题推到**基础设施层**的来源。此前的 harness 讨论停在三个层次：单进程的 turn/runtime（`analysis/01`、`analysis/16`）、跨 session continuity（`analysis/15`）、组织级反馈（`analysis/14`）。本文的对象是一个托管平台上同时跑着成千上万个 agent 时，session、harness、sandbox 各自的生命周期与故障域。它给出的答案在形状上与操作系统的答案相同：不要让任何一层依赖另一层的进程存活，把每层做成可独立替换的接口，让"硬件"（容器）变成可随时销毁重建的 cattle。

**范围说明（2026-10-25）**：本仓库只覆盖自研、本地的 harness，不覆盖云托管 agent 服务的使用。本文描述的是 Anthropic 自家托管产品的架构，这里只吸收对**本地自研 harness** 同样成立的三件事——凭据在结构上不可达、沙箱作为工具调用（崩溃即工具错误）、harness 循环无状态并能仅凭 session 日志恢复；舰队规模的托管与扩容不在本仓库范围内。

写作动机本身值得记录：作者明确说 harness 里编码着"模型做不到什么"的假设，并给出与 `analysis/19` 完全相同的实例——Sonnet 4.5 的 context anxiety 催生了 context reset，Opus 4.5 让它变成死重。文中还有第二个实例：把"大脑"放进单个容器，部分原因是早期模型还不能在多个执行环境之间推理。不同的是，`analysis/19` 在应用构建尺度上得出这条元规则，本文在**平台尺度**上为它付出过真实代价：为过期假设耦合在一起的三层，故障时互相拖死。

## 核心抽象

- **三接口虚拟化：Session / Harness / Sandbox**。Session 是 append-only 事件日志；Harness 是调模型并路由工具调用的循环；Sandbox 是执行环境。指导原则是"**对接口的形状有主见，对接口背后跑什么没有主见**"——与 OS 用文件/进程抽象在硬件更替中存活是同一条设计直觉。
- **Cattle, not pets**：容器不是被守护的宠物，而是以 `execute(name, input) → string` 的形式被调用的**工具**。容器崩溃被捕获为 tool-call error 回传给模型，由模型用 `provision({resources})` 重建。故障处理从"工程师救容器"变成"模型换容器"，把基础设施故障降级成了模型可见、可决策的普通事件。
- **无状态 harness**：session log 外置后，harness 进程本身不需要任何状态跨崩溃存活。恢复 = `wake(sessionId)` + 从最后事件继续，事件经 `emitEvent` 持久化。harness 因此可以像无状态服务一样水平扩展（many brains）。
- **凭据的结构性隔离**：跑模型生成代码的 sandbox 拿不到凭据，harness 也拿不到。两种模式：**auth 随资源打包**（sandbox init 时用 token 克隆仓库并织入本地 git remote，push/pull 正常而 token 不可见）与 **vault + proxy**（OAuth token 入库、代理按次取用）。原文的原则句是"harness 从未感知任何凭据"。
- **Session 兼作外置上下文对象**：session log 不只是审计日志，还是模型上下文窗口之外的**可恢复上下文**——harness 用 `getEvents()` 带位置切片地取回（可回卷、可重读、可变换以优化 prompt cache）。职责被刻意切开：session 只保证持久性与可用性，**上下文工程推给 harness**，理由是未来模型需要什么不可预测。

## 重要模式

### 故障域分离是可观测性的前提

耦合设计下"harness bug、丢包、容器崩溃看起来一模一样"（只有一个 WebSocket 事件流可看）。三接口分离后，每一层的故障有独立的表面：容器死 = tool error，harness 死 = wake 重建，session 永不死。本仓库已有的"域/运行时/模型/UI/trace 分离"讲的是**状态**的分离；本文补的是**故障**的分离——状态分离做得好而故障域不分离，debug 仍然是玄学。

### "把基础设施故障暴露给模型"是 ACI 的延伸

容器崩溃 → tool error → 模型决定 `provision()` 重建，这条链路把 mini-swe-agent 的"environment adapter"、Anthropic tool 文章的"可修复错误"原则推到了基础设施层：**工具错误的语义可以承载整台机器的死亡**。前提是错误消息本身要可行动——模型需要从错误里看出"这是一个可重建的资源"，而不是一句 stack trace。

### 凭据隔离的两档强度

"auth 随资源打包"是按资源锻造凭据（一个仓库一份、生命期与 sandbox 绑定）；"vault + proxy"是按调用取用凭据（每次工具调用由代理注水）。两档的共同点是**凭据从不进入模型可见或模型可写的位置**。这比 `analysis/18` 的"spawn 时清洗环境变量"强一个量级：清洗是防止泄露，隔离是让泄露在结构上不可能。

### 扩展模型：many brains / many hands

harness 无状态 ⇒ 扩展 = 起更多 harness；容器按需 provision ⇒ 没有待机死区。p50 首 token 降 60%、p95 降 90% 的数字说明**启动死区此前是主要延迟来源**。工程含义：一旦 harness 与 sandbox 解耦，"一个 agent"就不再绑定"一个进程/一台机器"，并发不再是编排问题而是资源调度问题。

### meta-harness：平台不选信仰

Managed Agents 不限定上面跑哪个 harness。这与本仓库"框架只是起点"的立场同向，但角色相反——**本仓库的 skill 是 harness 的消费者视角，本文是 harness 的宿主视角**：平台定义接口形状，harness 是可插拔的租户。

## 工程启发

- **自研 agent 平台时，先写三接口的接口契约，再写任何实现**。Session 的契约是 append-only + 可按位置切片；Harness 的契约是无状态 + wake 可恢复；Sandbox 的契约是一次 `execute` 一个输入一个字符串输出。三层各自可被 mock、可被替换、可被独立扩容。
- **凭据设计先于工具设计**。在把任何工具接进 sandbox 之前，先回答"这个工具需要的凭据走哪一档"（随资源打包 / vault+proxy / 不进 sandbox）。事后补的凭据隔离总是半吊子的。
- **session log 的消费方不只有恢复**：投影出模型可见消息（DeepSeek）、切片成外置上下文（本文）、回放测试（OpenAI Agents JS `ScriptedModel`）是同一份日志的三种消费者。把日志设计成事件溯源形态，三者共用一份存储。
- **给"模型可见面"做缓存友好变换**是 harness 的合法职责（本文允许 harness 变换 `getEvents()` 结果以优化 prompt cache），这与 07 综合的"prompt 前缀稳定是成本项"互补：前缀稳定性在事件源头上做（append-only、确定性排序），比在消费侧修补便宜。
- **基础设施层的"带日期假设"消融对象**是耦合决策本身（例如"三层同容器"），不只是 harness 组件。模型升级时除了重扫工具与 prompt 补丁，也要重扫部署拓扑。

## 适用场景

- 任何"凭据在模型可触达范围内"的本地 agent——两种隔离模式（凭据随资源打包、vault + 本地代理按次注入）是最小改造路径，单机即可落地。
- 进程会崩溃、而会话不能丢的本地长任务：session 日志外置 + 无状态循环 + `wake` 式恢复，和本仓库 `analysis/01`（Pi）、`analysis/18`（DeepSeek）的恢复模型同向。
- 本地用容器或虚拟机做沙箱的 harness：把沙箱当工具调用、把崩溃当工具错误返回给模型，避免"人工救容器"。
- **不在本仓库范围**：多租户托管平台、舰队规模扩容、VPC 互联——这些是云托管服务的问题。
- **不适合**：单进程、短生命周期的应用内 agent，三接口解耦是纯开销；只取凭据隔离一节即可。

## 注意

- 本文是 Anthropic **自家产品**的架构复盘，三接口的形状带有其业务形状（代码任务、git 资源、MCP 工具）；其他业务形态下 Sandbox 的接口可能不是 `execute → string`。
- 性能数字（60%/90%）来自其特定负载（启动死区主导），不可外推为通用收益。
- "harness 从未感知任何凭据"是对**托管平台**的断言；消费其平台的开发者仍需自己保证交给平台的东西不含凭据。
- vault + proxy 模式引入了代理自身的可用性与延迟，等于把一个 SPOF 换成了一个受控组件——文中未展开其故障模式。

## 对最终 skill 的影响

- `skills/design-ai-agent/SKILL.md`：在 `## Durable Execution and Side Effects` 内新增一段"session / harness / sandbox 各自是独立故障域"（无状态循环仅凭 session 日志恢复、沙箱作为工具调用且崩溃即工具错误、三类故障在日志里必须可区分），并在决策表加一行"崩溃不能丢会话"。2026-09-04 草稿中的"舰队规模基础设施解耦"整节与"托管 agent 平台"一档按本仓库范围收缩掉。
- `skills/secure-ai-agents/SKILL.md`：`## Sandbox and Subprocess Hygiene` 新增"凭据在结构上不可达"一条（凭据随资源打包、或 vault + 代理按次注入；harness 自身也不持有凭据）。
- `skills/build-ai-agents/references/source-map.md`：登记本文与快照路径。
- `analysis/07-overall-agent-analysis.md`：共识矩阵的权限与状态边界两行补入凭据结构性隔离与故障域分离。
