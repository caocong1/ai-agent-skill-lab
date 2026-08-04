# OpenAI Codex 生产级 Harness 源码分析

> 分析版本：1.0 ｜ 最后更新：2026-08-04 ｜ 来源：OpenAI Codex（commit `9873cba8ce6d14e650e12cdc0dddd159ae6613d7`，详见 `analysis/SOURCE_INDEX.md`）

本仓库此前的 Pi、OpenAI Agents JS 和 Learn Claude Code 分别展示轻量 runtime、通用 SDK 与教学骨架；OpenAI Codex 则提供另一个极端：一个真实 coding-agent 产品的 harness 如何把模型 sampling、动态工具、context window、项目指令、sandbox、approval、streaming events、rollout 和多环境状态组合起来。

它最重要的学习价值不是复制 Rust 代码，而是验证“生产 harness 的复杂度主要长在边界和生命周期上”。核心 ReAct loop 仍然清晰，但每一步都必须与一致的环境快照、权限策略、事件流、持久化和失败恢复对齐。

## 核心抽象

- **Turn / Step / Tool Call 三层生命周期**。turn 对应用户可见工作单元；一次 turn 可包含多次 model sampling step；每个 step 又产生零到多个 tool call。context、telemetry、cancellation 与 state 需要明确属于哪一层。
- **Step context 是一致性快照**。模型看到的上下文、advertised tools、工作目录、permissions 与实际 tool execution 必须来自同一 request view，避免模型按旧能力计划而运行时按新能力执行。
- **Tool orchestration 是政策执行层**。工具 handler 不自行散落 approval/sandbox/retry 判断；中央 orchestrator 固定执行 approval → sandbox selection → attempt → denial classification → 有条件 escalation/retry。
- **Project instructions 有层级与 provenance**。`agents_md.rs` 从 project root 到 cwd 收集指令，受总字节预算约束，并保留来源路径/环境；这比把一段匿名字符串塞进 prompt 更利于诊断。
- **Rollout 是可恢复、可分析的产品数据**。session metadata、事件、tool 输出和状态被持续记录，用于 resume、fork、thread 展示、记忆与后续分析，而非只打日志。

## 重要模式

### `run_turn` 的 follow-up loop

`session/turn.rs` 在 turn 起点先处理 pre-sampling compaction、MCP/skill/plugin 依赖、hooks 与 context snapshot，然后循环构造 prompt、stream model response、执行工具、记录结果并判断是否需要 follow-up。只有模型不再请求工具、无 pending input、stop hook 不要求继续时才结束。

该 loop 与 Pi/mini-swe 的本质相同，复杂度来自中间保持的 invariant：输入注入要先记录、tool result 要按确定顺序回到 history、用户 steer 要在安全时机 drain、context limit 要在 tool continuation 前 compact。

### Context window rollover

Codex 不只“超长后总结”：它记录 token status、区分 pre-turn 与 mid-turn compaction、保存 initial context 注入位置，并在 rollover 后优先恢复 model/tool continuation。源码甚至提醒多次 compaction 会降低准确率，长 thread 应主动切分。

### Approval 与 Sandbox 的集中编排

`tools/orchestrator.rs` 先把 permission profile materialize 到 workspace roots，再计算 approval requirement 和 sandbox 类型。sandbox denial 不等于自动提权：是否允许 retry、是否需二次审批、网络策略与 unsandboxed execution 能否使用，都有显式分支与 telemetry。

### 动态工具与渐进式暴露

每个 step 从 tool router 生成 model-visible specs；skills、plugins、MCP servers 和 discoverable tools 可按输入提及与环境状态注入。工具 surface 不是 session 启动时永久固定，但变化必须与 step snapshot 绑定。

### 层级 `AGENTS.md`

项目根由可配置 marker 决定；从根到 cwd 逐层寻找 `AGENTS.override.md` / `AGENTS.md` 或 fallback 文件，在总字节预算内拼装。实现保留 provenance，但仍存在被截断、marker 误判和多层规则冲突等需要测试的边界。

### Event-first runtime

model stream、reasoning、tool item、turn diff、warning、token 与 lifecycle 都通过结构化事件对外暴露。UI 不需要直接窥探内部 mutable state；相同事件也支撑 telemetry、测试和回放。

## 工程启发

- 生产 harness 首先要定义生命周期所有权：哪些数据是 session 固定、turn 固定、step 快照、tool-call 临时，避免全局 config 在执行中漂移。
- approval、sandbox 与 retry 必须共同设计。单独有 approval prompt 但执行未受 sandbox 约束，或 sandbox denial 后静默无沙箱重试，都会破坏安全模型。
- instructions 应保留 provenance、优先级与 budget。诊断 agent 违反规则时，需要知道规则是否加载、来自哪里、是否被截断或被更近层覆盖。
- context compaction 要测试“初始约束是否仍在”“pending tool continuation 是否保持顺序”“多轮 compaction 后是否还能完成”，而不只测试 summary 字符串生成。
- rollout schema 是公共兼容面：resume/fork/UI/eval 都依赖它，版本化、截断、脱敏和迁移应与数据库 schema 同等严肃。
- 动态工具加载要在每个 step 构造一致快照；不要一边把旧 tool spec 给模型，一边用新 registry 执行。

## 适用场景

- 设计本地 coding agent、IDE agent 或需要 shell/file/network 实际执行的通用 agent runtime。
- 系统需要流式 UI、steering、resume/fork、多 context window、动态 MCP/skills/plugins 与平台级 sandbox。
- 用作生产边界清单和源码参考，而不是作为简单 agent 的默认架构模板。
- 对一次性内部 workflow，直接复制 Codex 的多层 runtime 会明显过度工程。

## 注意

- 仓库变化快，本分析绑定完整 commit；具体模块名、feature flag 和协议字段容易漂移，复用前应重新核对当前版本。
- 开源仓库展示客户端与核心 runtime，但不等于公开模型训练、服务端 inference 或云产品全部实现。
- 复杂实现不能自动证明每条路径安全；应重点看 tests、policy materialization、platform sandbox 差异和 fallback 路径。
- `AGENTS.md` 加载、tool discovery 和 compaction 都有 token/字节预算，预算耗尽是静默行为风险，必须可观测。

## 对最终 skill 的影响

- `skills/design-ai-agent/SKILL.md`：补充 turn/step/tool-call 生命周期、step-consistent snapshot 与 rollout 作为兼容面。
- `skills/test-ai-agents/SKILL.md`：新增 compaction continuation、instruction provenance/budget、dynamic tool snapshot 和 sandbox escalation 测试。
- `skills/review-ai-agents/SKILL.md`：审查 approval/sandbox/retry 是否集中且无静默提权，状态是否按生命周期分层。
- `skills/build-ai-agents/references/source-map.md`：登记 Codex commit 与 `session/turn.rs`、`tools/orchestrator.rs`、`agents_md.rs`、`compact.rs` 等核心文件。
- `analysis/07-overall-agent-analysis.md`：把 step snapshot、集中 policy orchestration 与 rollout 兼容面纳入生产 harness 共识。

