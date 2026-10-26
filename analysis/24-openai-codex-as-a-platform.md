# OpenAI Codex as a Platform 分析：成熟 harness 作为可内嵌组件的三层接入

> 分析版本：1.0 ｜ 最后更新：2026-10-25 ｜ 来源：OpenAI《Codex as a platform: build on the open agent harness》（发布 2026-08-19，抓取 2026-10-25）｜ 快照：`raw/docs/openai-codex-as-a-platform.md`

`analysis/16` 从源码研究过 Codex harness 的内部生命周期（turn/step/tool-call、step snapshot、approval/sandbox/retry 编排、rollout）。本文是它的外部视角续篇：OpenAI 把这个 harness 明确定位为**可复用层**——开源、可内嵌、可改造，并给出三层接入契约。对本仓库而言，它的价值不在新机制，而在**形态选择**：在"自研 tool loop"与"把整个 agent 交给别人跑"之间，有一条此前没被清晰表述的中间道路——**在自己的产品里内嵌一个成熟的开源 harness，三层接入都以本地进程运行**。

本文的边界划得很清楚：开源的那一层是 harness 与集成面，模型访问与托管服务是另外的东西。按本仓库的范围（只覆盖自研、本地的 harness），这里只讨论内嵌开源 harness 这一形态；同期出现的托管形态（OpenAI 2026-09-10 的 Agents API）是云服务，不在范围内。

页面引用的 ARC-AGI-3 数字需要按出处读（2026-10-25 核对）：GPT-5.6 Sol 在官方 harness 下得 13.3%，打开"保留推理"与"压缩"两个上下文设置后得 38.3%、输出 token 少 6 倍。它证明的是**同一模型在不同上下文管理设置下的方差可以非常大**——与 `analysis/17`（mini-swe-agent 证明 scaffold 影响可测）同向，也是 `analysis/25-harness-shelf-life-research.md` 的一条证据；但它不是"内嵌这个 harness 就能提升三倍"的证据，提升来自上下文管理而非审批、流式或工具。

## 核心抽象

- **Agent loop 是可复用层**：context 管理、工具使用、streaming、审批、失败处理是"harness 承担的最难部分"，也是可被一次实现、处处复用的部分。产品（App/CLI/IDE 扩展）只是这个引擎之上的不同前端。
- **三层接入契约**：`codex exec`（非交互脚本、CI、后台任务，返回结构化输出）→ Codex SDK（程序化 start/resume/stream）→ codex app-server（一个本地 Codex 进程，承载持久会话、事件流与审批处理，可中断工作、对外暴露工具）。按集成深度递进，分别对应"一次性任务 / 可编程会话 / 产品级 agent 面板"。
- **开发者三个控制点**：**interface**（保留现有 dashboard/editor，不必迁就聊天 UI）、**context 与 tools**（包括应用自有 MCP 服务）、**operational boundaries**（agent 在哪跑、能访问什么、什么需要审批、工作怎样被观察、结果怎样回到业务系统的记录源）。这三个控制点几乎逐条对应本仓库 skill 的核心规则：工具/上下文是 agent 接口、权限在执行边界、完成与证据要回到可审计的记录。

## 重要模式

### 按集成深度选层，而不是按功能选层

三层不是功能集不同，而是**会话语义**不同：exec 没有会话连续性诉求，SDK 有了可恢复会话，app-server 把会话生命周期和审批事件流交还给宿主产品。这复刻了本仓库 harness 三层模型的第二层（session continuity）——**跨入 app-server 层的标志恰恰是需要宿主接管审批与持久会话**。源码侧的印证：app-server 的 10 个服务端→客户端请求方法（含全部审批请求）在 2026-08 到 2026-10 之间没有变化，是一个稳定的嵌入接缝（见 `analysis/16`）。

审批语义在各层不同，要显式确认：exec/SDK 层的审批通常由策略配置隐式决定；app-server 层的审批是宿主要处理的显式事件；而 Python SDK 的默认审批模式是**由模型审查**（auto review），不是"全部询问人"。内嵌时最容易犯的错，是以为默认就是最保守的那一档。

### 应用自有 MCP 作为 context/tools 的注入点

示例应用（Relay 货运 dashboard）里，agent 的调查能力来自**应用自有的 MCP 工具**，而非通用 web 工具；改签等有后果的写操作要求人工审批。这个形状就是 07 综合"用 MCP 复用外部能力、不替代宿主 runtime"的官方版实现：宿主把领域能力做成 MCP，把 harness 当本地运行时内嵌。

### "embed, don't rebuild" 是形态光谱的新档位

此前形态光谱从"tool loop 自研"直接跳到"durable graph/workflow 自研"。本文补上的档位是：**自研宿主 + 内嵌开源 harness**。适合的场景特征：想要产品级 harness 质量（审批/沙箱/恢复/流式），但不想自己维护这些机制；同时要保有自己的 UI、领域工具与权限边界。同一时期出现的同类形状还有 Vercel `@ai-sdk/harness` 的 HarnessAgent（把 Claude Code / Codex / Pi 等本地 runtime 放到同一个流接口后面，见 `analysis/02-agent-framework-patterns.md`）与 Claude Agent SDK（把 Claude Code 当库内嵌，见 `analysis/28-claude-agent-sdk.md`）——"内嵌一个现成的本地 harness"已不是单家做法。

## 工程启发

- **在"自研 vs 复用"决策里加一个前置问题**：任务需要的 harness 质量（审批、沙箱、恢复、流式）是否已有维护良好、可在本地运行的开源实现？有 → 先评估内嵌，把自研精力留给领域工具与权限边界。
- **内嵌时锁定的三样东西**（interface / context+tools / boundaries）正好是宿主必须自己设计的三样——内嵌 harness 不减少设计量，只是把"引擎正确性"外包。团队不能以为内嵌 = 无需权限设计。
- **审批是内嵌集成的关键接缝**：确认每一层的默认审批语义（策略隐式 / 宿主显式事件 / 模型审查），把审批 UI 与审批事件的对接当作主要工程量，与 `analysis/23` 的模型审批层衔接。
- **引用 ARC-AGI-3 这类数字时连同出处与机制一起引用**：它量化的是上下文管理设置的方差，不是某个 harness 的整体优劣。

## 适用场景

- 已有本地产品（dashboard、IDE 插件、内部工具）要加 agent 能力，且不想自研 loop/审批/恢复机制。
- CI/后台自动化（exec 层）：一次性任务、无会话连续性诉求。
- **不适合**：需要把 harness 本身作为差异化资产维护的团队；宿主平台与 Codex 的执行环境假设不兼容的场景；强隔离合规场景需先核验开源仓库的 sandbox 边界是否满足自身威胁模型。
- **不在本仓库范围**：托管形态（Agents API 一类由厂商运行 harness 的服务）。

## 注意

- 本文是平台推广文档，不是工程复盘；与 `analysis/14`/`analysis/16` 的工程细节互补阅读，不宜单独作为架构依据。
- 采用方案例为页面自述，2026-10-25 已逐条核对出处；其中 Thrive/Crete 一例里 Codex 是"评测驱动、提 PR 的改进回路"，不是嵌入的 app-server 运行时，不能当作内嵌形态的案例引用。
- 三层接入的 API 细节会随 Codex 版本演进；本仓库只登记形态判断，不冻结 API 形状（与 README 非目标一致）。上游仓库自 2026-08 起不再接受外部 PR，`codex mcp-server` 子命令已移除——内嵌前按当时的版本核对。

## 对最终 skill 的影响

- `skills/design-ai-agent/SKILL.md`：`## Workflow vs Agent` 新增"内嵌成熟的本地开源 harness（exec / SDK / app-server 式分层）"这一形态，写明宿主仍拥有 interface、context+tools、operational boundaries 三个设计责任；决策表新增对应一行。
- `skills/build-ai-agents/SKILL.md`：Core Rules 新增一条"写循环之前先评估能否内嵌一个维护良好的本地开源 harness；内嵌不免除边界设计"。
- `skills/build-ai-agents/references/source-map.md`：登记本文与快照路径。
- `analysis/07-overall-agent-analysis.md`：形态光谱新增"内嵌开源 harness"档。
