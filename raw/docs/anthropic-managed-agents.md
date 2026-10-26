# Anthropic《Scaling Managed Agents: Decoupling the brain from the hands》结构化摘要

> **来源**：https://www.anthropic.com/research/managed-agents（原 `/engineering/managed-agents`，现 308 重定向至此；页面 `og:title` 为 "Scaling Managed Agents with stable interfaces"，正文 H1 为本文件标题）
> **发布**：2026-04-08（作者 Lance Martin、Gabe Cemaj、Michael Cohen）
> **抓取**：首次 2026-09-04（WebFetch，AI 辅助结构化转述）；2026-10-25 逐条复核（正文自 2026-09-04 以来未变，页面 2026-10-18 的修改时间是站点批量重存）
> **性质声明**：本文件是**转述式结构化摘要**，不是原文镜像。数字与引语以原文为准；需要原文请访问上方官方链接。

## 问题背景

1. **harness 假设会过期**。harness 代码里编码了"模型做不到什么"的信念，这些信念随模型进步而失效（原文以超链接指向 Bitter Lesson，正文未点名）。文中有**两个**实例：(a) Claude Sonnet 4.5 有 context anxiety（临近上下文上限时草草收尾），当时的解法是 harness 级 context reset；Claude Opus 4.5 没有这个行为，reset 就成了死重。(b) "大脑"最初被放进单个容器，原因之一是早期模型还不能在多个执行环境之间推理——这条假设同样随模型变强而失效。
2. **"宠物"问题**。最初设计把 session、harness、sandbox 放进同一个容器：失败意味着丢 session，无响应的容器得由工程师"救活"；调试只有一个 WebSocket 事件流——harness bug、丢包、容器崩溃看起来一模一样，实际上无法调试。用户数据也在同一容器里，导致工程师实际上不能 shell 进去调试。
3. **连接性不灵活**。自带 VPC 的客户必须对等互联网络或自己托管 harness，因为 harness 假设资源与它同容器共存。
4. **安全缺陷**。耦合设计下，Claude 生成的代码与凭据同容器运行；一次 prompt injection 就能让 Claude 读取自己所在的运行环境（其中有凭据），而被盗的 token 还能用来开启不受限的会话。

## 核心架构：三个可独立替换的接口

Managed Agents 把 agent 虚拟化为三个接口（类比文件/进程等"比硬件活得久"的 OS 抽象）：

- **Session**——发生过一切的 append-only 日志；
- **Harness**——调用 Claude 并把工具调用路由到基础设施的循环；
- **Sandbox**——代码与文件编辑的执行环境。

指导原则：**对接口的形状有主见，对接口背后跑什么没有主见**。

## 命名机制与模式

- **解耦大脑与手/会话**：Claude + harness（大脑）与 sandbox/工具（手）及事件日志（session）分离，各自可独立故障、独立替换。
- **Cattle, not pets**：容器以 `execute(name, input) → string` 的形式作为**工具**被调用；崩溃作为 tool-call error 捕获并回传给 Claude，由它用 `provision({resources})` 重新初始化。
- **无状态 harness 恢复**：session log 外置后，harness 崩溃不需要任何进程内状态存活；用 `wake(sessionId)` / `getSession(id)` 从最后一个事件恢复；事件用 `emitEvent(id, event)` 持久化。
- **凭据隔离（安全边界）**：token 在 sandbox 内**结构性不可达**。两种模式：(a) **auth 随资源打包**——sandbox init 时用 access token 克隆 git 仓库并织入本地 git remote，push/pull 正常工作而 agent 永远摸不到 token；(b) **vault + proxy**——MCP OAuth token 存入安全库，专用代理按次取用凭据。原文断言："harness 从未感知任何凭据。"
- **Session 作为外置上下文对象**：session log 是模型上下文窗口之外的**可恢复上下文**，通过 `getEvents()` 带位置切片地审读（回卷、重读）。harness 可以对取回的事件做变换（例如为 prompt cache 命中率）。职责分离：session 只保证持久性与可用性；上下文工程推给 harness——因为未来模型需要什么不可预测。原文把"上下文作为可在代码里检视的对象"这条思路链接到 Recursive Language Models（arXiv 2512.24601）。
- **Many brains**：harness 无状态 ⇒ 扩展 = 起更多 harness；容器只在真正被工具调用需要时 provision，削减启动死区。结果：p50 首 token 时间降约 60%，p95 降 90% 以上。
- **Many hands**：任何"手"都只是 `execute(name, input) → string`，支持自定义工具、MCP server 或 Anthropic 自有工具；harness 不关心 sandbox 是"容器、手机还是 Pokémon 模拟器"；大脑之间可以互相交接"手"。
- **Meta-harness**：Managed Agents 刻意不限定上面跑哪个 harness，Claude Code 或窄任务专用 harness 皆可承载。

## 工程规则

- 不要把模型局限烤进 harness 代码——定期重审这些假设。
- 基础设施组件要可替换、各自容错，而不是需要人照看的"宠物"。
- 跑模型生成代码的 sandbox 要**结构性**隔绝凭据，而不是依赖窄化 token 权限（后者假设"聪明模型用受限 token 做不出坏事"）。
- 上下文要持久化、可恢复地存在模型上下文窗口之外；把不可逆的压缩/裁剪决定往后推。
- 只对接口有主见：假设 Claude 需要状态操纵（session）、计算（sandbox）、many-brain/many-hand 扩展——但**对大脑和手的数量与位置不做任何假设**。

## 与本仓库既有来源的关联提示

- "harness 组件是带日期的假设"与 `analysis/19`（Anthropic 2026-03）同源同规，本文给出基础设施级的第二个实例（context anxiety → reset → 死重）。
- session 外置事件日志与 `analysis/18`（DeepSeek Harness 事件溯源 session log）形成远端对照：一个为跨容器恢复，一个为投影出模型可见消息。
- `execute(name, input)` 工具化容器与 mini-swe-agent 的"environment adapter"及 Anthropic tool 文章的 ACI 原则一致。
