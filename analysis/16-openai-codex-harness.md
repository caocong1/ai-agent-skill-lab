# OpenAI Codex 生产级 Harness 源码分析

> 分析版本：1.1 ｜ 最后更新：2026-10-25 ｜ 来源：OpenAI Codex（commit `970111f6`，main HEAD 2026-10-23，最新稳定版 rust-v0.164.0，详见 `analysis/SOURCE_INDEX.md`）
>
> 1.1 变更：快照从 `9873cba8`（2026-08-04，≈ 0.147.0-alpha.7）推进到 `970111f6`（+3,734 commits，其间 33 个稳定版 0.147.0–0.164.0；HEAD 位于 0.165 开发线，领先 rust-v0.164.0 的分叉点 91 个 commit）。1.0 引用的 8 条路径全部有效，核心判断全部成立并被加强。新增 `### Guardian：策略与人之间的模型审批层`（该子系统在 1.0 快照里已发布，1.0 漏记）与 `## 0.147 → 0.164 增量（2026-10-25 核验）`。就地更正三处：compaction 准确率警告限定到 1.0 快照并注明已删除；`rollout.rs` 只是 re-export 薄壳；orchestrator 的越沙箱重试契约已反转。

本仓库此前的 Pi、OpenAI Agents JS 和 Learn Claude Code（`analysis/01-pi-source-analysis.md`、`analysis/02-agent-framework-patterns.md`、`analysis/10-learn-claude-code.md`）分别展示轻量 runtime、通用 SDK 与教学骨架；OpenAI Codex 则提供另一个极端：一个真实 coding-agent 产品的 harness 如何把模型 sampling、动态工具、context window、项目指令、sandbox、approval、streaming events、rollout 和多环境状态组合起来。`analysis/24-openai-codex-as-a-platform.md` 是同一 harness 的外部接入视角。

它最重要的学习价值不是复制 Rust 代码，而是验证"生产 harness 的复杂度主要长在边界和生命周期上"。核心 ReAct loop 仍然清晰，但每一步都必须与一致的环境快照、权限策略、事件流、持久化和失败恢复对齐。1.1 用约 80 天、3,734 个 commit 的上游演化检验了这个判断：`run_turn` 的 loop 形状没有变，变的全是边界——step 快照从"能力"扩到"设置"，授权绑定到发起它的 turn，越沙箱重试必须重审，工具目录只追加，每一段上下文带来源，自动续跑有了无进展上限。这些恰好是本仓库分别从 `analysis/18-deepseek-harness.md`（单调 guard、`model-visible ⟺ logged`）和 `analysis/23-claude-code-auto-mode.md`（机械边界之上的模型审批层）学到的东西，Codex 在一个生产单体里同时落地了它们；1.0 漏记的 Guardian 就是 auto mode 在 Codex 里的对应物。

## 核心抽象

- **Turn / Step / Tool Call 三层生命周期**。turn 对应用户可见工作单元；一次 turn 可包含多次 model sampling step；每个 step 又产生零到多个 tool call。context、telemetry、cancellation 与 state 需要明确属于哪一层。
- **Step context 是一致性快照**。模型看到的上下文、advertised tools、工作目录、permissions 与实际 tool execution 必须来自同一 request view，避免模型按旧能力计划而运行时按新能力执行。（1.1 补：快照范围从"能力"扩到"设置"——每个 step 另捕获一份不可变的 `ResolvedStepSettings`：模型元数据、reasoning、service tier、审批策略与 reviewer、personality；token 预算也按该 step 的模型解析。已捕获的 step 与动作不随之后的设置更新改变。授权 grant 则刻意不冻结：实时生效，但归属发起它的 turn。见增量节 1、2。）
- **Tool orchestration 是政策执行层**。工具 handler 不自行散落 approval/sandbox/retry 判断；中央 orchestrator 固定执行 approval → sandbox selection → attempt → denial classification → 有条件 escalation/retry。（1.1：shell、patch、MCP、网络与 `request_permissions` 现在走 `Session` 里同一条审批管线；越沙箱重试的契约已反转，见 `### Approval 与 Sandbox 的集中编排`。）
- **审批者可以是模型**（1.1 新增；子系统在 1.0 快照已存在）。`approvals_reviewer` 决定审批请求交给人还是交给 Guardian；Guardian 是一个被限制为只读、无网络、不能再申请审批的 Codex 子会话。它不替代沙箱，只替代"问人"这一步。
- **World State 是模型可见状态的差分层**（1.1 新增；1.0 快照已存在，1.0 未记）。AGENTS.md、权限、环境、模型说明、工具等模型可见状态被拆成带稳定 ID 的类型化 section（`codex-rs/core/src/context/world_state/`）；每个 step 只渲染"相对上一份快照，模型接下来必须被告知什么"，快照写进 rollout（首份全量，之后是 RFC 7386 merge patch），resume 时据此判断模型已经看过什么。这是 Codex 版的 `model-visible ⟺ logged`；增量工具目录就是其中一个 section。
- **Project instructions 有层级与 provenance**。`agents_md.rs` 从 project root 到 cwd 收集指令，受总字节预算约束，并保留来源路径/环境；这比把一段匿名字符串塞进 prompt 更利于诊断。（1.1：provenance 已从 AGENTS.md 扩到每一段上下文，并成为 Guardian 判断"谁的话能授权"的输入，见增量节 5。）
- **Rollout 是可恢复、可分析的产品数据**。session metadata、事件、tool 输出和状态被持续记录，用于 resume、fork、thread 展示、记忆与后续分析，而非只打日志。（1.1 更正：`codex-rs/core/src/rollout.rs` 在两个快照里都只是 61 行 re-export 薄壳，持久化实现在 `codex-rs/rollout`、`codex-rs/thread-store`、`codex-rs/state` 与新拆出的 `codex-rs/history`，1.0 把薄壳列为核心文件不准确。rollout 现在还保存模型永远看不到的数据，见增量节 9。）

## 重要模式

### `run_turn` 的 follow-up loop

`session/turn.rs` 在 turn 起点先处理 pre-sampling compaction、MCP/skill/plugin 依赖、hooks 与 context snapshot，然后循环构造 prompt、stream model response、执行工具、记录结果并判断是否需要 follow-up。只有模型不再请求工具、无 pending input、stop hook 不要求继续时才结束。

该 loop 与 Pi/mini-swe 的本质相同，复杂度来自中间保持的 invariant：输入注入要先记录、tool result 要按确定顺序回到 history、用户 steer 要在安全时机 drain（1.1：`instant_interrupt` 默认开启后，新输入会直接抢占流中的请求，见增量节 7）、context limit 要在 tool continuation 前 compact。

1.1 复核：loop 形状未变，只多了 post-turn 与后台 compaction（后者开发中）的检查点。一处两个快照都有、1.0 没记的缺口：mid-turn compaction 成功后直接 `continue`，源码注释的理由是只要 compaction 能把 token 压到远低于上限，就不必担心死循环。这条回路没有显式计数器，收敛靠 compaction 的效果（推论：compaction 反复无效时，只能靠上下文超限报错等其它路径终止）。

### Context window rollover

Codex 不只"超长后总结"：它记录 token status、区分 pre-turn 与 mid-turn compaction（1.1：另有可选的 post-turn 一档）、保存 initial context 注入位置，并在 rollover 后优先恢复 model/tool continuation。在 `9873cba8` 快照里，`compact.rs` 每次 compaction 成功后都会向客户端发一条警告：长 thread 与多次 compaction 会让模型变得不那么准确，应尽量开新 thread 保持短小。（1.1 更正：这条警告已于 2026-10-19 删除（#55355），PR 只写了"停止发出"，没有给出理由。删除不等于问题已解决——可能是 compaction 质量提升让它不再成立，也可能只是产品取舍，现有材料无法区分，记为待核验。本仓库"compaction 不等于 continuity"的结论来自 `analysis/15-anthropic-long-running-agent-harness.md`，不依赖这条警告。）

### Approval 与 Sandbox 的集中编排

`tools/orchestrator.rs` 先把 permission profile materialize 到 workspace roots，再计算 approval requirement 和 sandbox 类型。sandbox denial 不等于自动提权：是否允许 retry、是否需二次审批、网络策略与 unsandboxed execution 能否使用，都有显式分支与 telemetry。

（1.1：`9873cba8` 的头注释把顺序写成 approval → 选沙箱 → 尝试 → 被拒后以提权策略重试，并注明重试 "no re‑approval thanks to caching"；`970111f6` 的头注释改为 Guardian 批准只适用于被审的权限，"escalating a sandboxed attempt requires a fresh review of the retry"（#54263）。代码里的区分是：人和 hook 的批准保留原有的重试范围，Guardian 的裁决只覆盖被审动作；需要越沙箱时，审批动作被改写成实际重试所需的 `RequireEscalated` 权限，再审、再缓存。提权本身也从"开关"变成"增量"：放宽文件写，但保留被拒的读与网络策略，保不住就拒绝，见增量节 3。）

### Guardian：策略与人之间的模型审批层

（1.1 新增。代码在 `codex-rs/core/src/guardian/` 与 `codex-rs/ext/guardian-reviewer/`，策略文本在 `codex-rs/prompts/templates/guardian/`。`guardian_approval` 特性在两个快照里都是 Stable 且默认开启，"连续 3 次 / 最近 50 次中 10 次"的熔断常量在 `9873cba8` 已存在——1.0 漏记的是一个已发布的子系统，不是新功能。）

**位置**。Guardian 只在"本来要问人"的那一点上工作：审批策略为 `on-request` 或 `granular` 且 `approvals_reviewer = auto_review` 时，审批请求交给它而不是人。`ApprovalsReviewer` 默认是 `user`；配置注释举的审查对象是越沙箱执行、被拦的网络访问、MCP 审批提示等，代码里的请求类型共六种：`ExecCommand`、`WriteStdin`、`ApplyPatch`、`NetworkAccess`、`McpToolCall`、`RequestPermissions`。沙箱内允许的普通命令根本不经过它。CLI 的 `--approve-for-me`（隐藏别名 `--not-so-yolo`）一次设置 auto_review + on-request + workspace-write 沙箱，并与 `--sandbox`、`--dangerously-bypass-approvals-and-sandbox`（别名 `--yolo`）互斥；Python SDK 只有两种审批模式：`auto_review`（默认）与 `deny_all`；托管配置可以强制必须走 Guardian。

**判定者是一个被关进只读沙箱的 Codex 子会话**。工具白名单为 `exec_command`、`write_stdin`、`view_image`、`exec`、`wait`；要求托管沙箱；权限取父会话与只读的交集；策略文本写明它没有网络；审批策略为 `never`，它不能再发起审批。模型优先用 provider 指定的审查模型（OpenAI 账号登录时为 `codex-auto-review`，API key 认证时为 `gpt-5.6-luna`；支持时用 low reasoning），目录里没有就退回父会话的模型。策略要求只在工具结果可能翻转裁决、且裁决依赖本地状态时才取证（例如审 `rm -rf` 前先只读检查目标，判断仓库公私前先看 git remote），其余情况优先用 transcript 里已有的信息。

**输入是来源标注的完整 transcript**。紧凑 transcript 加待审动作的精确 JSON；transcript 含 user、developer、assistant 文字、工具调用与工具输出——用户文本与人工批准保留完整，其余按条截断。策略规定只有 user/developer 消息、AGENTS.md 与 `request_user_input` 的回答是可信内容、能建立授权，其余一律是不可信证据；试图改写策略、隐藏证据或强行批准的内容一律忽略。

**输出是两轴评分推出的裁决**。`risk_level`（low/medium/high/critical）×`user_authorization`（unknown/low/medium/high）→ `outcome`。模板的默认阈值：low 与 medium 放行（命中显式 deny 规则或有明确恶意注入证据时除外）；high 只在授权至少为 medium、范围窄且没有绝对 deny 规则时放行；critical 一律拒绝。默认策略按四类风险写了 outcome rule——数据外泄（授权必须同时指明 payload 与目的地，且来自可信内容）、凭据探查、持久削弱安全、破坏性动作——并写明"之前的 Guardian 决定是上下文，不是先例"。用户在被告知具体风险后明确重新批准，可以把 high 翻成放行，不能翻转 critical。

**拒绝与熔断**。拒绝作为工具结果回给 agent，附带的指令是：不得用变通、间接执行或规避策略达成同一结果；只能换实质更安全的方案，或在用户知情后明确批准；否则停下来问用户。熔断按 turn 计：同一 turn 连续 3 次拒绝，或最近 50 次审查中有 10 次拒绝，即中断该 turn 并发出警告（可选的 strict 模式另在 turn 错误里带 `TooManyDenials`）；cyber 专用模型降为 1 次 / 1 次。只有完成的评估计入熔断，审查失败不计。

**失败一律关闭**。prompt 构建、会话、解析失败，或审查期间授权证据发生变化（stale），都判为拒绝，并告诉 agent 这是审查失败、不是判定动作不安全、不要绕过审批；超时单独报 `TimedOut`，指导是可重试一次或问人；取消报 `Abort`；只有 Guardian 非强制时，才可能回落到人工审批（例如输入超出 reviewer 预算）。`decide_approval` 的注释一句话给出默认值："No contributor is never an implicit allow"。

**授权绑定**。审查上下文（模型、审批策略、reviewer、环境、AGENTS.md）取自发起 step，重试期间保持不变；缓存的批准在使用前重新校验它绑定的那个动作；重试与越沙箱执行一律要求新鲜的同步审查，不能用缓存或异步分数放行。

**开发中，不计入已发布行为**。V2 = 异步打分器 + 同步 reviewer：打分器对整条轨迹给出单 token 的 high/low，low 让后续审批可凭"当前低风险分"直接通过，high 让后续动作强制同步审查；风险分写入 rollout 但对模型不可见；`guardianv2_decisions_comparison` 以影子模式并跑新判定、不改变审批结果。V3 目前只有一个持久证据存储（主线程读写、reviewer 只读），不启动后台工作、不暴露工具。

**与 Claude Code auto mode 对照**（`analysis/23-claude-code-auto-mode.md`）。相同之处：

- 位置相同：机械边界之上、人之下，人只接熔断。`--approve-for-me` 把 auto review 与 workspace-write 沙箱捆在一起，沙箱内的写不经审查，与 auto mode 的 Tier 2（项目内写跳过分类器）同构。
- deny-and-continue 加两道拒绝预算。"连续 3 次"两家相同；第二道 auto mode 是累计 20 次，Codex 是最近 50 次中 10 次的滑动窗口，且按 turn 重置。
- 授权匹配都是逐动作的：auto mode 默认按意图拒绝，"清理我的分支"不授权批量远程删除；Codex 写明模糊意图、紧急语气、"想要某个终态"都不授权具体的高风险动作。
- 都优先用独立的、更便宜的判定模型（Codex 在目录里没有审查模型时退回执行模型本身）；auto mode 的单 token 快筛与 Codex V2（开发中）的单 token 异步打分是同一种成本设计。
- 无人值守时，模型审批的另一侧只能是拒绝：auto mode 在 headless `-p` 下熔断即终止，Codex 的 Python SDK 根本没有"问人"模式。

不同之处：

- **判定上下文相反**。auto mode 是 reasoning-blind：结构性剥掉 assistant 文字、工具输出与工具描述，原文有输入消融支撑这一选择。Guardian 给来源标注的完整 transcript，还允许只读取证；它的外泄规则本身就需要工具输出（payload 要追溯到原始数据，网络请求要追溯到触发它的命令）。代价是注入内容进入了判定上下文，只靠指令层的"不可信证据"标签抵御。Anthropic 的输入消融显示，给自家分类器加入 assistant 文字与工具结果会变差——这是对 Codex 选择的一条反向证据，但它测的不是"来源标注 + 只读取证 + 按类别要求追溯 payload"这种组合；Codex 仓库里没有任何误报/漏报数字。判断：这是两种押注，现有材料不能判定优劣，也不能把 Anthropic 的消融结论直接移植过来。
- **分流的依据不同**。Guardian 只审越过沙箱或策略边界的请求，沙箱是第一道边界；auto mode 按动作类别分级，shell、web、外部工具、subagent 都进分类器。
- **机械约束写得更多**。失败语义（fail-closed、失败不计熔断、超时与拒绝分开报）、授权绑定（发起 step、缓存批准再校验、stale 即失败）、越沙箱重审都在 Codex 代码里；auto mode 的公开材料没有描述这些（不等于它没有）。
- **披露不同**。auto mode 公开了 FPR/FNR 和主要失效模式（同意范围误判）；Guardian 只有代码与策略文本。

顺带一条线索：2026-09-04 的 auto mode 草稿曾把"不把一次既往审批当作模式"写成 auto mode 的设计规则（`analysis/23-claude-code-auto-mode.md` 已更正为失效模式）。Codex 策略里确实有一条相近但更窄的规则：Guardian 自己之前的裁决不构成先例；用户知情后的重新批准仍然有效。

判断：两家都说明，模型审批层能不能成立，取决于它被多少机械约束包住（判定者沙箱化、失败语义、授权绑定、熔断），而不是判定模型有多强。

### 动态工具与渐进式暴露

每个 step 从 tool router 生成 model-visible specs；skills、plugins、MCP servers 和 discoverable tools 可按输入提及与环境状态注入。工具 surface 不是 session 启动时永久固定，但变化必须与 step snapshot 绑定。（1.1：在 Responses Lite 下，工具目录已改为只追加——首个请求发完整目录，之后只追加新增或变更的定义，移除用 developer 通知表达；2026-10-19 起 Stable 且默认开启，见增量节 4。）

### 层级 `AGENTS.md`

项目根由可配置 marker 决定；从根到 cwd 逐层寻找 `AGENTS.override.md` / `AGENTS.md` 或 fallback 文件，在总字节预算内拼装。实现保留 provenance，但仍存在被截断、marker 误判和多层规则冲突等需要测试的边界。（1.1：发现算法与 `InstructionProvenance` 未变；新增四条边界——未受信任的项目跳过项目级 AGENTS.md；`project_doc_max_bytes` 改为跨环境共享的单一预算；加载时执行环境的文件系统权限，被拦即让 thread/turn 启动失败；fallback 文件名拒绝路径语法。见增量节 5。）

### Event-first runtime

model stream、reasoning、tool item、turn diff、warning、token 与 lifecycle 都通过结构化事件对外暴露。UI 不需要直接窥探内部 mutable state；相同事件也支撑 telemetry、测试和回放。（1.1：hook 事件从 11 个增至 14 个：新增 `Interrupt`，以及只观察的 `PreModelRequest` / `PostModelRequest`（#55144，不能否决请求，也不能改写模型上下文）。审批流程内部重写的同时，app-server 发给客户端的 10 个请求方法（含全部审批请求）在两个快照间完全一致：内部大改，协议不动。）

## 工程启发

- 生产 harness 首先要定义生命周期所有权：哪些数据是 session 固定、turn 固定、step 快照、tool-call 临时，避免全局 config 在执行中漂移。
- approval、sandbox 与 retry 必须共同设计。单独有 approval prompt 但执行未受 sandbox 约束，或 sandbox denial 后静默无沙箱重试，都会破坏安全模型。
- instructions 应保留 provenance、优先级与 budget。诊断 agent 违反规则时，需要知道规则是否加载、来自哪里、是否被截断或被更近层覆盖。
- context compaction 要测试"初始约束是否仍在""pending tool continuation 是否保持顺序""多轮 compaction 后是否还能完成"，而不只测试 summary 字符串生成。
- rollout schema 是公共兼容面：resume/fork/UI/eval 都依赖它，版本化、截断、脱敏和迁移应与数据库 schema 同等严肃。
- 动态工具加载要在每个 step 构造一致快照；不要一边把旧 tool spec 给模型，一边用新 registry 执行。
- （1.1）**冻结什么、保持什么实时，要写成所有权表**。Codex 的答案是：模型与审批设置、token 预算、工具与 skill 目录按 step 冻结；授权 grant 实时生效但归属发起 turn；skill 读取的授权检查保持实时。只冻结不归属，后台单元会在新 turn 里丢掉或借用权限；只实时不冻结，模型按旧设置计划而 runtime 按新设置执行。
- （1.1）**批准的范围就是被审过的权限**。缓存的批准不能覆盖比它更宽的重试；重试要按实际所需的权限重新审、重新缓存。提权是在边界上开一个具体的口子，不是关掉边界。
- （1.1）**模型审批者自己也要被机械约束**：只读、无网络、不能再申请审批；失败一律 fail-closed，并明确告诉被审的 agent "这是审查失败而不是判定不安全"，免得它把失败读成"换个办法绕过去"；熔断只计完成的判定。
- （1.1）**上下文变化用追加表达**。工具增删、说明变更都以"追加定义 + 通知"表达，不改写已发送的前缀；每个定义按与键序无关的内容哈希判定是否变化。
- （1.1）**无进展上限按活动测量，而不是按轮数**。连续空续跑、连续执行失败都要阻断目标，被中断的续跑也要计入，子 agent 的 token 计入根目标——任何一条绕开计数的路径都会让自动续跑变成无限循环。
- （1.1）**持久化以完成为准**。compaction 输出缓冲到响应完成才写入历史，替换前要求非空摘要；已接受的用户输入在失败路径上也先落盘再报错。半截写入比失败更难恢复。观测性检查（如 Codex 的沙箱完整性检查）则要写明它不拦截，否则会被当成边界。

## 适用场景

- 设计本地 coding agent、IDE agent 或需要 shell/file/network 实际执行的通用 agent runtime。
- 系统需要流式 UI、steering、resume/fork、多 context window、动态 MCP/skills/plugins 与平台级 sandbox。
- 需要在沙箱之上加一层模型审批的本地 agent：Guardian 提供了一套完整的参照实现（判定者沙箱化、失败语义、授权绑定、熔断），可与 `analysis/23-claude-code-auto-mode.md` 对照选择判定上下文。
- 用作生产边界清单和源码参考，而不是作为简单 agent 的默认架构模板。
- 对一次性内部 workflow，直接复制 Codex 的多层 runtime 会明显过度工程。

## 注意

- 仓库变化快，本分析绑定完整 commit；具体模块名、feature flag 和协议字段容易漂移，复用前应重新核对当前版本。（1.1：约 80 天 3,734 个 commit。判断一项行为是否已发布，要看 `codex-rs/features/src/lib.rs` 里每个 flag 的 `Stage` 与 `default_enabled`，并留意例外：`instant_interrupt` 默认开启，却仍标 `UnderDevelopment`。）
- 开源仓库展示客户端与核心 runtime，但不等于公开模型训练、服务端 inference 或云产品全部实现。（1.1：`token_budget` 的 history/notes 工具、`codex-auto-review` 审查模型都依赖 OpenAI 服务端；自研本地 harness 只能迁移其模式。Codex 云端任务与托管服务不在本仓库范围。）
- 复杂实现不能自动证明每条路径安全；应重点看 tests、policy materialization、platform sandbox 差异和 fallback 路径。
- `AGENTS.md` 加载、tool discovery 和 compaction 都有 token/字节预算，预算耗尽是静默行为风险，必须可观测。
- （1.1）**来源的读法变了**。2026-08-17 起仓库不再接受外部 PR（#39089）；PR 由 `copyberry[bot]` 从内部投影，正文是变更摘要，讨论不公开，"为什么删"常常查不到（如 #55355）。release 正文只有 alpha 预发布版近乎为空（只有 `Release 0.164.0-alpha.12` 这样一行），稳定版有完整说明（0.147.0 约 2.55 万字符，0.164.0 约 2.78 万字符）；2026-08-23 审查"release 正文为空、无法判定"的记录不成立，更正见 `.planning/freshness-reviews/2026-10-25-source-freshness-review.md`。
- （1.1）**Responses Lite 绑定**。增量工具目录、逐段来源元数据等只对 Responses Lite 生效，内置模型目录里除 gpt-5.5 外全部走 Responses Lite。#38499 对所有 prompt 打开 `parallel_tool_calls`，但 Responses Lite 请求在构造时仍把它关掉；真正落地的并行是调度层让只读工具共享锁（#52245）。对接其它 provider 的自研 harness 不能把这些当成 Codex 的通用行为。
- （1.1）**接入面收缩**。`codex mcp-server` 已删除（#42993）；app-server 的 2,469 行 README 于 2026-09-07 删除（#43421），同路径后来重新长出一份只记新增行为的 626 行说明，完整协议说明已不在仓库内。

## 0.147 → 0.164 增量（2026-10-25 核验）

按本仓库的主题组织，而不是按版本。阶段标注取自 `codex-rs/features/src/lib.rs`：**开发中** = `UnderDevelopment`（不对外）；**可选** = 已发布但默认关闭（Stable 但默认关，或配置项默认关）；未标注者为已发布且默认开启。括号内为上游 PR 号。

### 1. Step 一致快照：从能力扩到设置

- `StepContext`（`codex-rs/core/src/session/step_context.rs`，25 → 95 行）新增一份不可变的 `ResolvedStepSettings`（`codex-rs/core/src/session/step_settings.rs`）：模型元数据、reasoning、service tier、审批策略与 reviewer、personality。进行中的 step 保持已捕获的设置，thread 设置更新只作用于后续工作；源码注释写明替换快照不改变已经捕获它的 step 或动作（#40651）。
- token 预算、context window 与模型可见的窗口说明按每个 step 的模型解析，说明变化时只发一次替换或移除通知（#41162）。
- 审批读取发起 step 的设置，覆盖命令、patch、权限、沙箱重试与远程网络（#40821）；后台进程的审批用其所属环境，环境不可用时拒绝自动批准（#46556）。
- 插件与 skill 目录在构建工具之前按 step 准备好，配置重载只影响后续 step，skill 读取的授权检查保持实时（#50050、#55357）；subagent 继承发起 step 的环境快照（#55331）。
- 服务的主题：**step-consistent snapshot**。1.0 的快照只回答"模型这一步能做什么"，现在也回答"以什么设置去做"。

### 2. 授权绑定到发起它的 turn

- turn 级 grant 与严格审查状态存于 `TurnContext`，被已捕获的 step 和后台 code-mode 单元保留；权限响应记到发起请求的那个 turn，即使下一个 turn 已经开始；session 级 grant 跨 turn 共享（#49880）。PR 写明的动机：后台单元若按"当前 turn"查 grant，会丢掉已批准的权限，或用上别的 turn 的权限。
- Guardian 的审查上下文同样取自发起 step；越沙箱重试不能沿用 Guardian 的批准（#54263，见上文）。
- 服务的主题：**authorization bound to the issuing turn**。本仓库已有"授权不从序列化状态继承"；Codex 补上运行时的一半——在同一个进程里，授权也不跨 turn 漂移。

### 3. 提权：部分放宽，保不住约束就拒绝

- 审批合并为一条管线：permission hook、reviewer 路由、批准缓存与问人移入 `Session`（#37128），MCP 工具调用（#38108）、被拦的网络访问（#38299）、`request_permissions`（#38701）陆续并入；`approvals.rs` 由 289 行增至 876 行。
- 显式提权获批后放宽文件写，但保留沙箱、被拒的读与网络策略；单凭命令 allow 规则不会放宽文件访问；本地沙箱不可用、或远程 exec server 无法保住这些限制时拒绝提权；提权后的终端被跟踪，之后的 `write_stdin` 仍要审（#49353、#46499）。`write_stdin_approval` 已发布且默认开启。
- 网络策略贯穿 harness 自己的 HTTP/WebSocket 客户端：逐跳检查重定向目标，读响应体期间持有可撤销的许可，策略拒绝不重试（#47389）；新策略安装时取消它不再允许的请求，策略加载失败即阻断网络（`codex-rs/app-server/README.md`）。
- 沙箱完整性检查接到命令与文件操作之前，但**只是观测**：失败或超时都不阻止执行（#51843）。凭据遮蔽（经网络代理注入凭据）**开发中**，默认关，项目配置不能覆盖（#52302）。
- 服务的主题：**fail-closed escalation**。提权是边界上的增量；能放宽的只有被审过的那一维，其余维度保不住就整体拒绝。

### 4. 前缀稳定：工具目录只追加

- Responses Lite 会话的首个请求发完整工具目录，之后只把新增或变更的定义作为 `additional_tools` 条目追加进历史，移除的工具与 namespace 说明变化用 developer 通知表达；每个定义按与 JSON 键序无关的哈希比较（#50540）。2026-10-19 起 Stable 且默认开启（#55368）；这些定义随 rollout 持久化，resume 与远程 compaction 使用历史里的定义（#50435）。实现在 `codex-rs/core/src/context/world_state/top_level_tools.rs`。
- 工具名冲突在建表时检测；严格模式（**可选**，`[features.tool_registry].error_on_tool_collisions`）在发出请求前让 turn 失败（#37020）。
- 扩展可以在模型看到之前检查或替换 MCP 结果（#41202）；每个 MCP 工具可配置输出上限，生效值写进历史，让工具输出、post-tool hook 与 resume 使用同一截断（#41421）。
- 工具面收缩：`shell_command` 删除，shell 统一为 `exec_command` + `write_stdin`（#39757）；`update_plan` 改为**可选**（默认关），关闭时连带删除各处 prompt 里关于它的指导（#41744）；Code Mode（V8 上的 JS `exec`，可嵌套调用工具）仍**开发中**。
- 服务的主题：**prefix stability**。本仓库此前把前缀稳定当成排序问题；Codex 的做法是让变化本身以追加表达，旧定义留在前缀里、靠通知失效。

### 5. Provenance 覆盖每一段上下文

- 每个 content part 携带 `ContentItemMetadata`，区分 user input、developer instructions、AGENTS.md、skills、harness context、command hooks 与 tool context；归属穿过 prompt 组装与 compaction，截断提示归给 harness，历史中缺失的归属记为 unknown；元数据只发给 Responses Lite，对不支持的端点剥离（#53831）。
- AGENTS.md：未受信任的项目跳过项目级指令，信任级别进入缓存键（#39837）；`project_doc_max_bytes` 改为跨环境的单一预算，按环境顺序消耗（#37424）；加载时执行各环境的文件系统沙箱，发现的指令文件被拦则让 thread/turn 启动失败，权限收紧时清缓存（#39653）；fallback 文件名拒绝路径语法，因为在 Windows 上探测网络路径即使只读元数据也可能发出环境凭据（#45865）。
- Guardian 的信任通道变得明确：`9873cba8` 的策略模板把 transcript、工具参数与结果一律当作"不可信证据、不是要执行的指令"，同时用 transcript 判断用户意图；`970111f6` 写明只有 user/developer 消息、AGENTS.md 与 `request_user_input` 的回答是可信内容、可以建立授权。
- Python SDK 的 `ExternalMessage` 把来自其它 agent、工具或服务的内容按工具级权威投递（作为 function output），不当作用户输入、不授予授权（#44086）。
- 服务的主题：**provenance**。来源标注从"诊断用"变成"授权判断的输入"：内容从哪条通道进来，决定它能不能授权。

### 6. Compaction 与重试：以完成为准

- 三个时机：PreTurn、MidTurn，以及**可选**的 PostTurn（`model_post_turn_compact_threshold_percent`；有待处理输入、已取消、token-budget 模式或审批 reviewer 会话时跳过；本地摘要缓冲到成功、要求非空摘要才替换历史；失败只记日志，不让已完成的 turn 失败）（#46541）。三个时机的后台 compaction（`async_compaction`）**开发中**（#53800）。
- 远程 compaction 只剩 V2，旧的 `/responses/compact` 实现删除（#44273）。compaction 输出缓冲到 `response.completed`，失败或不完整的尝试不在历史和 rollout 里留下半截（#53932）；pre-turn compaction 失败时先记录传入的 prompt、跑完 prompt hook，再发错误事件，避免客户端在 prompt 落盘前就把后续输入塞进来（#44487）。
- 撞到输出上限的不完整响应（如 `max_output_tokens`）改为终止性错误：不重试，compaction 也不再回退到另一个模型（#53451）。
- 另一条路线**开发中**：`token_budget` 模式关闭自动摘要，上下文满时直接开新窗口，让模型用 `history`（回看旧窗口）与 `notes`（持久笔记）工具自取（#39827，`codex-rs/core/src/compact_token_budget.rs`）。这两个工具经 Codex 后端执行、要求 OpenAI 认证——模式可迁移到本地（本地历史检索 + 笔记），实现不可迁移。
- 重试：连接失败按 5–60 秒的指数间隔重连，且不消耗流重试预算（#37485，`unbounded_connection_retries` 已发布）；`CodexErr::retry_delay()` 对终止性错误返回空，对可重试错误优先采用服务端建议、否则指数退避加抖动，服务端建议只决定时机、不延长重试上限（#46540，`codex-rs/core/src/responses_retry.rs`）；content filter 拦截后，每次重试前追加 developer 指导：不复现、不绕过、简述限制、给出允许的替代（#49119）。
- 服务的主题：持久化与恢复（`analysis/07-overall-agent-analysis.md` 共识矩阵的"持久化执行与副作用治理"行）——写入以"完成"为准，失败路径不留半截，也不靠换模型硬撑。

### 7. 打断与排队

- `instant_interrupt`（2026-10-07 起默认开启，但仍标 `UnderDevelopment`，#51812）：新输入打断请求准备、流式输出与重试退避；重置 WebSocket 与续接状态，下一个请求重发完整历史；保留已完成的 commentary，丢弃未完成的 assistant 文本（#48141）。这改写了 1.0"steer 在安全时机 drain"的描述：抢占点从 step 边界前移到了流的中间。
- 持久化的用户消息队列：thread 空闲时按 FIFO 派发；被中断或失败时消息留在队列里；输入落盘后才移除队列项（#37204）。
- 并行：#38499 对所有 prompt 打开 `parallel_tool_calls`（受 Responses Lite 限制，见注意）；#52245 让只读工具（skill/memory/history 读取、插件与 agent 列表、当前时间、剩余上下文、`get_goal`）并行，目标的创建与更新保持串行。

### 8. 完成与续跑上限

- Goals 在两个快照里都已发布且默认开启；新增的是无进展上限：自动续跑连续 3 个 turn 没有任何活动（没有非空回复、推理摘要或工具活动）即把目标标为 `blocked`（#44320）；被中断的自动续跑也计入——此前一个反复打断续跑的 `PreCompact` hook 就能让目标永远运行（#52640）；连续 3 个 turn 出现 `exec` 执行宿主失败且没有任何工具成功，同样阻断目标（#41454）；子 agent（含孙 agent）的 token 计入根目标的预算（#41183）。实现在 `codex-rs/ext/goal/src/accounting.rs`。
- Guardian 按 turn 计的拒绝熔断是同一思路在审批层的版本。
- 服务的主题：**completion/continuation caps**。上限按"有没有进展"测量，并把中断、委派这些会绕开计数的路径都算进去。

### 9. Rollout 兼容面

- 历史条目包进 `ResponseItemEnvelope`，compaction 与归一化改写条目时保留信封（#38045）；本地线程默认改为分页历史，旧模式保留为显式 legacy（#47900）。
- 新增持久化：带 response/turn/thread 归属的 token 用量，resume 不必扫描到最近一次 compaction checkpoint 之前（#41912）；`additional_tools` 定义（#50435）；compaction checkpoint 的 resume 元数据（#47323）；Guardian V2 的 `SecurityRiskScore`——两种历史模式都写入，但从模型上下文、用户可见历史、搜索、fork 与重建的对话中排除（#38363）。持久化的命令输出截到 64 KiB，保留首尾（#50427）。
- `thread/rollback` 删除、由 `thread/revert` 替代，但保留历史上的 `ThreadRolledBack` 标记与旧错误的反序列化，旧 rollout 仍可回放与迁移（#44915）。
- 服务的主题：rollout 是兼容面。API 可以删，旧记录必须仍然读得懂；同一份 rollout 里可以有模型永远看不到的数据。

## 对最终 skill 的影响

1.1 本轮（suite 2.3.0）实际落地：

- `skills/design-ai-agent/SKILL.md`：`## Loop Design` 的 step 快照扩到模型设置，审批绑定发起它的 step，每段上下文都留 provenance；`## Completion Judgment` 增加自动续跑的无进展上限；花费上限覆盖子 agent 树。
- `skills/design-agent-tools/SKILL.md`：`## Prompt Prefix Economics` 改为"上下文只追加"（工具目录以追加增量与移除通知表达）；`## Compaction Strategy` 增加失败安全——只用完整响应里的非空摘要替换历史，压缩失败时保留已接受的输入。
- `skills/secure-ai-agents/SKILL.md`：`## Approval Automation Layering` 把 reasoning-blind 改为两种生产判定上下文之一（只看用户消息与裸工具调用 vs 来源标注的完整记录 + 只读、无网络的调查），共同约束是只有用户 / 开发者来源能构成授权、审查者自己的旧裁决不是先例；审查失败即拒绝且不计入拒绝预算；无人值守只有"审查"与"全部拒绝"两种模式；`## Authority Boundary Design` 增加越沙箱重试必须重审、提权是增量且保不住其他限制就拒绝、授权绑定发起的 turn。
- `skills/test-ai-agents/SKILL.md`：越沙箱重试被重审、审查失败或超时即拒绝。
- `skills/review-ai-agents/SKILL.md`：反模式增加"审查失败或超时被当作放行""缓存的批准覆盖了要求更多的重试""自动续跑没有无进展计数"。
- `skills/build-ai-agents/references/source-map.md`：Codex 更新到 `970111f6`，以 `codex-rs/rollout/src/recorder.rs` 替换 re-export 薄壳，补 Guardian、step 设置、重试与 feature flag 的路径。
- `analysis/07-overall-agent-analysis.md`："权限/审批"与"前缀经济学"两行补入本节结论；"release 正文为空"的待办更正为"只有 alpha 预发布版为空"并标为已消费。

提议但本轮未采纳：

- 新输入可以抢占流中的请求（重发完整历史、丢弃未完成输出）、被中断的续跑计入上限、子 agent 用量计入根目标预算（design-ai-agent）：受体积预算限制，留在本文；花费覆盖子 agent 树一条已落地。
- 用与键序无关的内容哈希判定工具定义变化、撞输出上限的不完整响应是终止性错误（design-agent-tools）：实现细节，留在本文。
- 审批决定读取实时设置、观测性检查被当作边界（review）：前者已由"审批绑定发起它的 step"覆盖。

1.0 既有：

- `skills/design-ai-agent/SKILL.md`：补充 turn/step/tool-call 生命周期、step-consistent snapshot 与 rollout 作为兼容面。
- `skills/test-ai-agents/SKILL.md`：新增 compaction continuation、instruction provenance/budget、dynamic tool snapshot 和 sandbox escalation 测试。
- `skills/review-ai-agents/SKILL.md`：审查 approval/sandbox/retry 是否集中且无静默提权，状态是否按生命周期分层。
- `skills/build-ai-agents/references/source-map.md`：登记 Codex commit 与 `session/turn.rs`、`tools/orchestrator.rs`、`agents_md.rs`、`compact.rs` 等核心文件。
- `analysis/07-overall-agent-analysis.md`：把 step snapshot、集中 policy orchestration 与 rollout 兼容面纳入生产 harness 共识。
