# DeepSeek Harness 插件化 Agent Runtime 分析

> 分析版本：1.1 ｜ 最后更新：2026-10-25 ｜ 来源：DeepSeek AI, deepseek-harness（commit `1f81c047`，tag `dsh-v0.2.1-rc.3`，2026-10-23 prerelease，详见 `analysis/SOURCE_INDEX.md`）

DeepSeek Harness（`dsh`）2026-08-13 开源，是 DeepSeek 官方的 agent harness，MIT 许可，TypeScript 单仓（1.1 更正：1.0 写的"478 个 workspace 包"无法从 b150a551 的源码树复现——按当时 `pnpm-workspace.yaml` 的 glob 实数约 245 个成员，其中 `packages/*/*` 227 个；1f81c047 时约 366 个，其中 `packages/*/*` 343 个），构建在 vendored 的 [Cordis](https://github.com/cordiverse/cordis) 微内核之上，口号是 **"Everything is a Plugin"**：模型适配器、工具注册表、session log、agent loop 本身都是插件，都能从配置替换，没有一个"特权内核"可打补丁。

它对本仓库的价值不在于"又一个 coding agent"，而在于两点其他来源都没有同时做到的事：

1. **它把 harness 拆成了可命名、可替换、可核验的接缝（capability seam），并逐子系统写下了契约级文档**。`analysis/16-openai-codex-harness.md` 展示了生产 harness 的边界，但 Codex 是 Rust 单体；`analysis/10-learn-claude-code.md` 展示了机制的最小骨架，但是教学实现。DeepSeek Harness 第一次让"生产强度 + 明确接缝 + 公开契约"三者同时可读。
2. **它把"模型看到什么"变成了一等工程对象**。仓库强制每个包的 README 写出 Model Experience（模型看到什么 / token 效应 / KV-cache 效应），并用脚本门禁检查。这把 `analysis/08-anthropic-writing-effective-tools.md` 的 token 效率原则升级成了组织级的、机械可检的约束，并补上了本仓库此前完全缺失的一个维度：**KV-cache 经济学**。

它同时处于 developer preview，README 明确写着"会有破坏性变更"。本分析吸收其结构与契约，不把版本级 API 当作稳定引用。（1.1：这句仍成立，但范围已收窄——API 仍可随时破坏，已发布构建写下的 session 数据不再可以，见增量一节。）

1.1 在 `1f81c047` 重新核验，与 1.0 的 b150a551（`dsh` 0.1.1-rc.2）相隔 9,254 个 commit、28 个 release（全部 prerelease）。最有教益的不是新增，而是**上游删掉了 1.0 推崇过的四样东西**：runtime invariant 注册表、Agent Teams 的 durable 信箱、模型可写的自修改工具集、"每个非平凡改动必须带 Agent Note"。新增里与本仓库最相关的是实验性 Auto review——与 `analysis/23-claude-code-auto-mode.md` 的分类器审批同形，并自陈了程序化工具调用里直接副作用不经审查的缺口；契约演进政策从"后端拒读旧格式"翻转为"已发布的 session 数据是义务"，可与 `analysis/20-mcp-2026-07-28-revision.md` 的弃用政策对照。正文里已失效的陈述原地标注"1.1"，事实与理由集中在 `## 0.1 → 0.2.1 增量（2026-10-25 核验）`。

## 核心抽象

- **Cordis 插件树 + profile/bundle 分层组装**。运行中的 `dsh` 是一棵 boot 时按顺序层叠出来的插件树：`bundle`（一组 Cordis 配置行 + 它挂载的代码）→ `profile`（命名组合，如 `web` / `headless`）→ profile 自身 `cordis.patch.yml` → home 级 patch → `--patch` 覆盖层。每一层都能按 id 定位并替换上一层插入的行。`dsh --profile web --dump-config` 打印真实启动的树，任何一行都能被自己的 patch 替换（1.1：另有 `--dump-config-schema` 打印 profile 条目的 JSON Schema）。这是"配置即组装"的彻底形态：扩展方式是"在旁边挂一个插件"，不是"改内核"。
- **Capability seam = Service Definition + Service Provider + Consumer 三角色**。一个"可替换能力"必须同时设计三个角色：声明接口与词汇的 Service Definition（拥有 `ctx.<key>`）、实现它的 Provider、使用它的 Consumer（通常是面向模型的工具）。`packages/shell` 是范式：`dsh-shell`（定义）/ `dsh-bash-local`、`dsh-bash-sandbox`（提供者）/ `dsh-tool-bash`（消费者）。仓库明确规定：**seam 是完整的能力，绝不用这个词指其中一个角色**。这个纪律的收益是"换一个 provider 就换掉整个产品面"——filesystem 与 subprocess 提供者共享同一个执行世界，把它们指向远程沙箱，Bash、PTY、LSP 一起搬走，不需要为任何 provider 开分叉。
- **Event-sourced session log 是唯一真相源**。session 是一条只追加的 `SessionEvent` 日志；模型历史是从日志 `deriveMessages()` **投影**出来的，不单独存储。原始 `assistant/chunk` 保留用于回放与 UI 保真（1.1：session format v2 起已无顶层 `assistant/chunk`——每次模型尝试结算为一条事件，紧凑的带时间戳流嵌入 `assistant/message`，失败、重试、取消的尝试记为只入日志的 `assistant/attempt`；system prompt 也成了日志里的 `system/message`，见增量）。fork、resume、transcript、telemetry、持久化全部从这条流派生。
- **`model-visible ⟺ logged` 不变量**。任何进入模型请求的东西都必须能从 session log 重建，并且有一个 runtime invariant 在断言它（1.1：后半句已失效——规则仍写在 `AGENTS.md` 与 `docs/architecture.md`，断言它的 runtime 检查已随整个 invariant 注册表删除，保证改由构造给出，见增量）。因此"新增一种模型可见输入"这件事的工程含义是"新增一个 session event 类型并从日志渲染"，而不是"在 prompt 组装里加一行"。（1.1 更正：上游虽用 ⟺ 符号，定义只有一个方向——进入请求的一切可从日志重建；日志里有大量只入日志、不进入模型消息的事件，如 `compaction/*` 锁与摘要记录、`assistant/attempt`、审批审计对 `approval/asked` / `approval/decided`。）
- **turn / step / round 三级循环**。step = 一次模型请求加上它引发的工具执行；turn = 零个或多个 step，从第一份输入被 claim 时开启，到"无债可还"时关闭；round = 包住一个 turn 的**外层策略迭代**（goal round、Ralph round）。round 计数属于那条策略，不统计 session 里的每个 turn。本仓库此前只有 turn/step 两级，缺了策略层。（1.1：glossary 另加 exchange——从一个接纳人类输入的 turn 起到下一个这样的 turn 为止，由通知唤醒的 turn 归入前一个 exchange。）
- **agent scope：两层、扁平、most-specific-wins**。一个贡献（工具、prompt section、变量、限制、监听器）要么全局，要么属于恰好一个 scope key（约定就是那个 live `Agent` 对象本身）。scoped 注册**不向 subagent 继承**；子树行为用 lineage 数据（`parentSession`、`delegationDepth`）表达，绝不用 scope 结构表达。同名 scoped 工具遮蔽全局同名工具（per-agent persona 与 per-agent 工具变体就是这么来的）。
- **插件而非改 loop**。新行为挂到有文档的扩展点上；要改 `agent-loop` 本身，必须同时更新 `docs/architecture.md`。架构文档里有一张"目标 → 机制"表，把二十多种常见扩展需求映射到具体扩展点。

## 重要模式

### 事件分三域，先选域再写代码

架构文档把"选对事件域"称为大多数改动的第一个决策：

- **Session events**（`turn/*`、`step/*`、`user/message`、`assistant/*`、`tool/*`）：追加到日志、必须在重载后仍然存在的**持久事实**。（1.1：durable 事件现为 `turn/*`、`step/*`、`system/message`、`user/message`、`assistant/message`、`assistant/attempt`、`tool/*`。）
- **Agent events**（`agent/pre-step`、`agent/request`、`agent/status`、`agent/turn-stopping`、`agent/request-error`）：携带活的 `Agent`，用于观察或拦截**进行中**的工作。
- **Capability events**（`fs/*`、`tools/*`、`telemetry/*`）：把策略和适配器挂到某个接缝上，**不需要 import loop**。

`agent/pre-step`、`agent/request`、`llm/stream` 和三个 `tools/*` 是 waterfall：监听器**必须调用 `next()`** 才委托下去，不调用就短路整条链。`agent/turn-stopping` 是 serial，没有 `next()`。

### `agent/pre-step`：决定"模型这一步看到什么"的唯一串行点

pre-step 收到独占的 claimed 批次（消息 + turn/step 坐标 + 取消 signal），返回 `reject`（不开 step）或 `enter(messages)`（用这批完整消息进入 step）。被 reject 或首次 claim 被改写为空，仍然会**关闭一个没有花费任何 step 的持久 turn**——日志记录了这次尝试。这是"拒绝也要留痕"的干净做法。

plan mode、workspace instructions（`AGENTS.md` 链）、skill catalog、session reference、time/tmux context 全部在这里落地，彼此不需要知道对方存在。

### 工具执行流水线：可扩展 waterfall + 单调 guard

```
tools/pre-execute (waterfall，可重排：hooks / permission / sandbox；结果为 allow / deny / ask)
  → 仅当 ask：ctx.approval 一次性提示（只有 allowed-once 放行；缺席或无法回答 = deny）
  → 已注册的 monotonic guards（scope-aware 的最终 pre-dispatch 策略，只能 deny 或弃权）
  → tools/execute (around-dispatch：timeout / retry / metrics)
  → 工具体 execute()
  → fs/write-intent | fs/edit-intent（仅 tool-fs 变更）
  → tools/post-execute (accept / block / replace / 追加 context)
  → 注册表外层归一化（快照抛出 → isError）
  → ToolDefinition.finalizeContent（最后的 content-only 不变量）
  → tools/result（同步通知，冻结的权威结果）
```

**（1.1 更正：顺序。）** 1.0 把 guard 画在审批之前。上游生成图 `docs/tool-execution-pipeline.md` 在 b150a551 与 1f81c047 两个快照里都是：pre-execute 返回 `ask` → `ctx.approval` → guards → around-dispatch；`docs/subsystems/tools.md` 把 `ToolGuard` 定义为 scope-aware 的**最终** pre-dispatch 策略。这不是排版问题：guard 站在审批之后，所以**一个已被人批准的调用仍可被 guard 否决，审批推翻不了 guard**——"guard 没有 allow"能构成安全不变量，前提正是它在最后。上图已按上游改正。

其中最值得偷的是 **`ToolGuard` 的返回类型故意没有 allow**：`undefined` 保留 waterfall 的决定，返回一个原因就是拒绝。因为 guard 没有"放行"结果，**监听器顺序无法把拒绝变回许可**。这是一个用类型系统表达的安全不变量，比"注意注册顺序"这类文档约定强得多。

配套的还有：`ApprovalOutcome` 是封闭四元组 `allowed-once | rejected | cancelled | unavailable`，调用方只在 `allowed-once` 时放行；缺失、不拥有、抛出或不符合契约的 answerer 都归一化成 `unavailable` 而不是打开闸门。session 级 `approval/policy` 的 `never` 在 waterfall 分发**之前**执行，所以后注册的 `prepend` answerer 也绕不过去。（1.1：四元组、`never` 先于任何 answerer、`ToolGuard` 无 allow 三条均未变。）

### PTC（1.0 称 Code Mode）：把工具调用换成写程序

`ctx.ptcRuntime`（1.0 时为 `ctx.codeRuntime`）让模型写一段程序，宿主把工具作为一个 binding namespace（`tools`）注入为 program 全局对象。参数与返回必须是无损 JSON；运行时把被拒绝的调用变成注入的错误类实例。失败分类是**正交独立上报**的：`exception` / `timeout` / `abort` / `worker-exit` / `invalid-output` / `output-limit`（1.1：另加 `protocol`——程序发了非法或超预算的控制流量，与 `sandbox-unavailable`——要求的隔离建立不起来）——预算到期不是异常，abort 不是 timeout，底座死亡（OOM）两者都不是。

安全上有一条关键规则：在 `mode: 'ptc'`（1.0 时为 `mode: 'code'`）下，只有**带 parent token 的子调度**才能执行原生工具名；模型直发的调用（无 parent）在进入策略流水线之前就被判为 `UNKNOWN_TOOL`。`isolation` 字段（1.0 列的取值为 `worker-thread` / `process` / `container`）被明确标注为**诊断标签，不是安全声明**（1.1：仍然如此；Node provider 现报 `process`，另有 `sandboxMode` 声明是否支持文件策略）。

（1.1：改名、独立进程执行与 `both` 形式的删除见增量；1.0 时上游其实有 `both` 形式，本仓库"与原生 tool loop 互斥"的说法当时是推论，见增量末的更正。）

### Spill：大输出落盘 + 不透明 locator + 检索提示

`ctx.spillStore.saveText()` 把超限的工具文本原样持久化，返回 `{ locator, bytes, retrievalHint }`。locator 是 branded 的**不透明**模型可见句柄——本地后端渲染成路径，远程后端可以是 URI 或 key，消费者用 `retrievalHint` 渲染而不是假设 `read` 总是正确的取回方式。策略消费者用 head/tail 预览 + spill 引用替换过大的行内结果，并且是 **best-effort**：保存失败保留原始行内结果，绝不把一次成功的调用变成 `isError`。（1.1：策略阈值由 UTF-8 字节的 `maxInlineBytes` 改为按估算 token 计的 `maxInlineTokens`，并覆盖图片结果。）

本地后端的写法本身就是一份安全模板：私有 0700 根目录、`sha256(sessionId)` 子目录、`open(path, 'wx', 0o600)` 独占写，使被植入的符号链接无法重定向。

### Compaction：锁包住整个操作，pruning 先于 summary

`compaction/start` → 摘要 → `compaction/summary` → 替换用的 `user/message`（带 `surfaceOp: { op: 'replace', start, end }`）→ `compaction/end`。**锁最后释放**，所以中途崩溃留下的是一个可检测的孤儿锁（有 start 无 end），而不是一个谎称"压缩完成"的 end。（1.1：字段已改名为 `startSeq` / `endSeq`；选区从第一个非 `system/message` 的 surface 节点开始，0 号节点上的 system prompt 永不被遮蔽。）

压力触发时，`compaction-basic` 会先调用可选的 `ctx.toolResultPruner` 做**工具结果剪枝**并用 `ctx.tokenMeter` 重新计量——**能靠剪枝把 surface 推进就不做摘要**。这比"直接上 LLM summary"便宜得多，与 `analysis/10-learn-claude-code.md` 的 cheap-first 分层压缩相互印证。区域边界保留 tool-call/result 配对但不保留整个 turn，所以一个超大 turn 的早期已关闭 step 可以被单独压缩。

失败的模型请求走 `agent/request-error`：只有当 surface 替换代数确实推进了才返回 retry，取消永远优先。

### Token meter：区分"provider 权威用量"与"启发式估算"

`ctx.tokenMeter.measure()` 返回一个脱离引用的不可变快照，含 `baseline.kind`：`usage` 表示最近一次成功调用的规范请求信封相同且总量不低于该次的完整启发式锚点；`estimated` 表示没有可复用的保守锚点，于是整包重新按固定启发式计价。`surfaceDeltaTokens` 是**有符号**的，同时保留增长与收缩。把"我以为的 token 数"和"provider 说的 token 数"分开命名，是很多自研 harness 缺失的一步。（1.1：`baseline.kind` 多了 `none`；计价按 provider/model route 进行，route 声明了图片 token 价格就按它算，否则沿用固定启发式。）

### Goal 域：把"目标"做成 session 内的持久状态，而不是另一个 loop

`goal` 是挂在既有 session 上的一个持久完成目标：`active` / `paused` / `blocked` / `complete` 相位、带修订号的 compare-and-set 变更、goal-round 上限、`blocked` 携带机器可路由的 kebab-case `code` + 人类可读 `message`。关键设计：

- **相位是持久的，激活是进程本地的**。`GoalActivation`（`armed` / `disarmed`）**故意不进入持久回放**，所以 resume 和 fork 之后必须经过一次人类授权的 resume 变更，才能重新开始自动工作。这是一条很聪明的"重启不自动续跑"安全阀。（1.1：新增 `goal/activation-changed` 把这个进程本地的边沿实时发布出去，仍不进入回放。）
- goal 是状态，不是调度器，也不是另一段会话；session log 仍是真相源。
- 同一 session 里无关的人类 turn **不消耗** goal-round 配额。
- （1.1 新）宿主发起的暂停会中止正在运行的 turn，模型在自己 turn 内的暂停则让该 turn 正常结束；模型的 create / edit / pause / resume 要求本 turn 有直接的人类请求；模型的 `resume` 只能重新 arm 未激活的 active 或 blocked 目标，处于 paused 相位的目标只能由人经 Web 或 `/goal resume` 恢复；自主 `blocked` 默认要求同一条件连续三轮。
- （1.1 更正：1.0 漏记）goal README 在 b150a551 就写着 **No independent evaluator**——记录 complete / blocked 的调用方即权威——并承认持有 `Session` 的进程内插件能伪造 `goal/change`，严格回放能检测，但这不是插件隔离。所以 goal 域证明的是"完成是跨 turn 的持久状态"，不是"完成判定离开了执行方"。

### Ralph：fresh-agent 循环作为一个普通插件

（1.1：包已移到 `packages/experimental/tool-ralph/`，0.1.6-alpha.1 起在所有默认组合里关闭，经 `packages/experimental/ralph-bundle/` 显式启用；底层引擎换成 `workflow-ptc`；自陈限制新增 **No enforced recursive-Ralph denial**——只有 prompt 指引，没有结构性禁止。原因见增量。）

`ralph({ objective, maxRounds? })` 把一个不可变目标交给一串**全新的**子 agent：每一轮起一个 fresh child，child 只收到不可变目标、当前轮次与上限、"共享工作区即权威"的指令，以及上一轮的结构化 handoff。父会话不注入，前一个 child 的会话也不注入。handoff 是归一化的有界结构化报告（`status: continue | complete | blocked` + summary + evidence + next steps + blocker），有显式的 `maxHandoffChars` 上限；无效、缺失或超限的报告**让整个 workflow 失败**，而不是被截断或被误当成配额耗尽。

它的自我限制写得比能力还清楚：**完成是 worker 的自我声明，没有独立评估者**；只有前台；工作区是唯一的跨轮长期记忆；一轮就是一个 fresh child，没有轮内 fan-out；普通 child 失败即终止整个 run，不重试；只有轮数约束总投入，token / 价格 / 墙钟预算是 deferred。（1.1：README 现在把评估者的前置条件也写了出来——独立定义的输入、工具权限、确定性检查、provider 选择、隔离与权限，缺一不能认证完成。）

值得注意的是它在架构上的位置：**没有为 Ralph 在 `agent-loop` 里加任何模式**，它只是 `ctx.workflowEngine` + `ctx.subagents` 上的一个普通插件，同 session 的 goal 域完全独立。

### Workflow：模型写编排脚本，引擎跑子 agent

`ctx.workflowEngine` 让 agent 运行一段模型写的编排**脚本**来启动子 agent。`meta` 和 `args` 是纯 JSON 数据，引擎在**任何脚本文本被求值之前**按 schema 校验并大声拒绝。`parallel()` / `pipeline()` 组合子对 `fatal` 错误（拼错的选项、越界的 schema、触发的上限）**重新抛出**而不是把该项映射成 `null`——per-item `null` 只保留给真正的 child 运行失败。`workflow/*` 事件是只观察的数据快照，携带 `WorkflowRunInfo` 而非活的 `WorkflowRun`，订阅者拿不到 `cancel`/`dispose`；每个监听器拿到自己的 payload 克隆，抛出被容纳并记录。

`WorkflowRun.result` **永不 reject**：脚本失败解析为 `stopReason: 'error'`；一旦取消，即使脚本自己永不结束，引擎也会在有界宽限期内强制结算 `cancelled`。等待 `result` 的消费者永远不会被卡死。（1.1：引擎由 worker-thread 换成 `workflow-ptc`——每次运行一个新 Node 进程，受调用方 session 的文件沙箱策略约束，与 PTC 共用同一个执行 provider；上述三条语义未变。）

### Agent Teams（experimental）：durable roster + mailbox + task DAG

（1.1：0.2.1-alpha.2 起信箱已删除，改为直投目标 inbox、接受或拒绝，无 outbox、无重试、无去重；花名册、任务 DAG 与 `writeScopes` 的建议性语义未变。见增量。下段保留 1.0 原文以便对照。）

`ctx.agentTeams` 是私有 opt-in 的协调接缝：持久花名册、任务板、信箱，层叠在可续聊的 subagent 之上。信箱的可靠性设计值得记：**Lead session 先存下完整的排队消息，只有当目标方的 pending inbox item 或 user message 已经持久化之后才确认送达**，"已排队减去已送达"就是恢复用的信箱。任务 DAG 的 `writeScopes` 是**归一化的建议性路径前缀，不是锁**——只产生重叠告警，不做互斥。

### Self-referential 工具集：agent 修改自己的运行时

（1.1：0.1.6-alpha.2 起 `cordis_define` / `cordis_run` / `cordis_stop` / `cordis_undefine` 已删除，模型只剩只读的 `cordis_inspect_list` / `cordis_inspect_query`，持久改动经 Plugin Manager。见增量。下段为 1.0 原文。）

`cordis_inspect` / `cordis_define` / `cordis_run` / `cordis_stop` / `cordis_undefine` 让模型检视当前进程的服务、插件 fiber、工具、client slot，并定义/运行/撤回自己写的动态插件（host 半边在 `node:vm` 里，browser 半边广播到打开的页面）。信任立场写得很直白：**vm 隔离全局但不是安全边界，把这套工具当作 bash 权限对待**。动态包只活在进程内存里，不写文件、不改配置、不跨重启存活、不能自动晋升为正式插件。

### Model Experience：把"模型看到什么 / 花多少 token / 破不破缓存"写进包契约

这是整个仓库最值得直接移植的工程实践。每个包的 README 必须以固定结构收尾：

```markdown
## Model Experience
### <请求上下文与触发条件>
#### What the model sees      ← 精确字段、生成目录锚链接，或逐字引用的稳定 prompt
#### Token effect             ← 固定 / 条件 / 保留 / 替换 / 有上限 / 零直接开销
#### KV Cache effect          ← append-only / prefix-stable / replacing / independent，并写明什么会让复用失效
## Known Limitations and Deferred Work
```

`verify-package-readme-model-experience.ts` 机械检查这个结构；无上下文效应的包只能用审计过的固定句式（`None, as …` / `Indirectly, through …`）。它的效果是：**任何一次 prompt 组装的改动，作者都必须当场回答"这会不会毁掉前缀缓存复用"**。KV-cache 影响从此不再是性能团队事后才发现的账单问题。

配套还有 `## Known Limitations and Deferred Work` 的强制章节和 allowlist 门禁——把"这个能力目前做不到什么"变成包契约的一部分，而不是散落在 issue 里。

（1.1：上述结构与两道门禁都未变。README 模板另加了 frontmatter `kind`（group / reference / library / bundle 各对应一种模板）、≤100 词且被门禁的 `## Summary`、`## Use this package`，以及显式声明"非权威"的 `### Dev Note`。这份契约的 rationale note 已归档冻结——上游把它当作已完成的决策，而不是仍在试验的东西。）

### Runtime invariants：断言权威关系，而不是断言存在性（1.1：已整体删除）

`ctx.invariants.register(packageName, installer)` 是包自有的运行时不变量注册表。约定极其克制：**只能断言权威事件流或可变数据的关系**，不能断言"某个服务存在"、"某个方法存在"、插件元数据或固定的纯函数样例。没有可断言的关系时，正确做法是导出一个**空 installer 并用 `No runtime invariant:` 开头解释为什么这个包没什么可查**——机械门禁会拒绝生成式的占位、没有解释的空实现和忽略 reporter 的实现。

（1.1：0.2.1-alpha.1 起 `@deepseek-ai/dsh-invariants` 与每个包的 `./invariant` 导出全部删除。1.0 还漏了一个当时就成立的事实：2026-08-03 的决定已把它们从出厂的 TUI / Web 配置里撤下，b150a551 时它们只在测试、示例与显式开发组合里运行。撤回经过与本仓库该改信什么，见增量。）

### Agent Notes：机械门禁化的 ADR

`.agents/notes/{proposed|implemented|rejected}/{class}/yyyy-mm-dd-topic.md`，路径编码生命周期与类别；`## Alternatives considered` 是**强制**章节（"记录一个决定却不记录它击败了什么，就是在邀请重新争论"）；implemented note 必须**随代码保持当前**（文件搬了、包改名了、默认值变了，要在同一次改动里更新事实）；proposal 期的标题（`## Proposal` / `## Migration plan` / `## Acceptance criteria`）在 implemented note 里**被门禁拒绝**；归档后的 note 永久冻结，不得编辑、翻译、重排或当作现状权威。**非平凡改动必须在同一个 PR 里带一个 Agent Note**（1.1：已放宽为只记录代码、测试与现有文档承载不了的长期决策理由，见增量）。

这是 `analysis/14-openai-harness-engineering.md` 的 "repository as system of record" 落到可执行门禁的具体形态。

### Defensive patterns：把出过的 bug 类写成规则

`docs/defensive-patterns.md`（1.1：已拆为 `docs/defensive-patterns/README.md` 加 `general.md` 等五个主题文件；下列七条仍原样在 `general.md`）每一条都是真实出过或差点出的缺陷类，直接写成防止复发的规则。最通用的几条：

- **正交结果独立上报**：一个进程可以同时 timeout **并且** exit 0（它捕获了信号）。`timedOut` / `signal` / `exitCode` 各自独立呈现，绝不把一个标志的报告嵌进另一个的分支里，否则调用方会把被腰斩的运行读成干净成功。
- **公共契约两边都要遵守**：实现可能以多种形态返回同一个结果（抛异常 / 发 `finish {kind:'error'}`），必须在公共 API 之前归一化，让消费者不必猜"这个异常来自 provider、包装层、日志还是我自己的组装"。
- **异步状态不是同步状态**：`agent.followup()` 没有 per-message 的完成或结果；几个排队的 follow-up、steering 和注入工作可能共享同一个 `running` 区间。真正拥有一次运行的自动化调用方**必须显式定义自己的区间**（例如"从这条消息的持久 inbox 收据到下一次整体 idle"），并把选出的输出描述为区间级而非因果归属。同时要显式处理"根本等不到"的分支，否则等待会挂死。
- **dispose 必须到达静止而不只是请求静止**：先关掉监听/通知注册表**再**杀子进程，然后 await 子进程退出。
- **在分发器里容纳回调异常**：一个用户监听器抛出，不能拒绝它所在的 promise，也不能饿死它后面的监听器。
- **绝不把环境和可预测路径交给不可信输出**：spawn 的命令拿到擦洗过的环境（丢掉 `*KEY*` / `*SECRET*` / `*TOKEN*` / `*PASSWORD*`），临时/spill 文件用私有 0700 目录、随机名、独占 owner-only 打开。
- **link 形状的路径用 unlink 删**：`lstatSync().isSymbolicLink()` 后 `unlinkSync`——unlink 只删链接本身，绝不跟着链接进入目标；递归 `rmSync` 只留给已知的真实目录。

## 工程启发

- **先设计接缝，再写实现**。要新增一个能力，先问"Service Definition 是什么、Provider 有几种、Consumer 是谁"。只写了其中一个角色，就还不是一个能力。这条纪律直接决定了远程沙箱、容器、E2B 这类替换是"换一个 provider"还是"改十处代码"。
- **把安全不变量编码进类型，而不是写进注释**。"guard 没有 allow 返回值"这一个设计，消灭了一整类"注册顺序导致的权限回退"缺陷。同理，approval 的封闭四元组 + `unavailable ⇒ deny` 消灭了"answerer 缺席时默默放行"。
- **`model-visible ⟺ logged` 值得作为自研 harness 的第一条不变量**。它同时买到：可回放、可审计、可 fork、可从崩溃恢复、可做 eval 归因。代价是"新增模型可见输入"变贵——这个代价是对的。（1.1：上游保留规则、删掉了旁路断言；它的成立靠构造——请求只能从日志构建，连 system prompt 也是一条日志事件——而不是靠一个只在测试组合里运行的检查器。）
- **turn 结束 ≠ 目标完成**。把 goal / round 做成 turn 之上的独立策略层，并且**让激活状态不持久化**，是长任务 agent 的一个安全默认：进程重启后不会自己接着跑。（1.1：DeepSeek 的 goal 域自己也没有独立评估者；要让判定离开执行方，还得另配 `analysis/19-anthropic-harness-design-long-running-apps.md` 那样的 evaluator。）
- **Ralph 式 fresh-agent 循环应该是插件，不是 loop 模式**。它证明了"每轮全新上下文 + 共享工作区 + 有界结构化 handoff"可以完全在既有 subagent/workflow 原语上组合出来。同时它自陈的限制（完成靠自我声明）恰好是 `analysis/19-anthropic-harness-design-long-running-apps.md` 补上的那块——两者合起来才是完整方案。（1.1：上游最后把它撤出了所有默认组合——一个连自身描述都在限定使用场景、完成判定也无人背书的工具，不该待在默认工具表里。）
- **给每一个进入 prompt 的贡献写 token 效应和 KV-cache 效应**。哪怕不引入门禁脚本，把这三个小标题加进内部包/模块文档，就能在设计期而不是账单期发现"这个功能每一步都在动前缀"。
- **区分"provider 权威用量"和"本地启发式估算"**，并让 delta 有符号。否则压缩策略会基于错误的数字触发。
- **正交失败独立上报**是可以立刻用在任何 subprocess / 工具执行层的规则：`timedOut`、`signal`、`exitCode`、`denied`、`runnerFailed` 各自成立，不要互相嵌套。
- **把"这个包目前做不到什么"写进 README 并做门禁**。它让消费者不必读源码就知道边界，也让 deferred work 不会假装成 bug。
- **（1.1）一件事只留一个 owner**。这一轮的删除几乎都在收回"第二个 owner"：旁路检查与测试、Team outbox 与 Agent inbox、生成代码插件与已安装 bundle、逐改动 note 与代码/测试/文档、混合调用形式与单一调用形式（推论，各条依据见增量）。加一个机制之前，先问已有的 owner 能不能承担它。
- **（1.1）把"不知道"如实告诉模型**。有 durable 开始记录而无结果的工具调用，模型看到的是"结果未知：只读或幂等才可重试，否则先核对外部状态或问人"；只有没有开始记录的调用才是"可以重试"。这是 `analysis/01-pi-source-analysis.md` 的 effect sandwich 缺的模型侧一半。
- **（1.1）持久数据比 API 先稳定**。API 可以随时破坏，只要每次破坏都在当下附一份迁移说明；用户磁盘上的 session 日志从第一个发布构建起就不能作废。

## 适用场景

- 需要一个可以整体替换模型 / 工具 / 沙箱 / 存储 / UI 的**产品化 agent runtime**，而不是一个固定形态的 CLI。
- 需要多形态部署（Web、headless、one-shot、ACP、JSON-RPC、SDK）共享同一套能力与日志语义。
- 需要把"agent 能不能修改自己的运行时"作为一等能力，并且愿意为此接受 bash 级别的信任面。（1.1：上游已把这项能力收窄为"经 Plugin Manager 安装持久 bundle，每次操作要求 full access 或逐次审批"，模型不再能在进程内即写即跑。）
- 需要对模型可见上下文做严格审计、回放和成本归因的团队。
- **不适合**：只需要一次工具循环的小功能；不愿承担 478 包（1.1 更正：`packages/*/*` 下 343 个包）monorepo 与 Cordis 心智模型的团队；需要立刻稳定 API 的生产集成（developer preview，明示会破坏兼容）。

## 注意

- **Developer preview**。版本 `0.1.1-rc.2`，README 与 `AGENTS.md` 都写明会有破坏性变更，`SESSION_FORMAT_VERSION` 保持在 `0` 且不做兼容承诺，后端拒绝旧的磁盘格式。任何"照抄 API"的做法都会很快失效；应该抄的是结构与不变量。（1.1 更正：后半句已失效。`dsh-v0.2.1-rc.3` 的 README 仍写 developer preview 与"会有破坏兼容的变更"，但只针对 API；`SESSION_FORMAT_VERSION` 为 4，已发布的格式按相邻版本迁移，已提交的世代永不移动或删除。）
- **Cordis 是被 vendored 并 rescope 到 `@deepseek-ai/*` 的**（`cordis` → `@deepseek-ai/cordis` 等 9 个包）。它同时说明了一个现实约束：把框架作为 peerDependency 的产品，发布自己就等于发布这一层，用上游名字发布等于在 registry 上占坑。这是供应链层面的真实取舍，不是纯技术洁癖。
- **`isolation: 'worker-thread' | 'process' | 'container'` 明确不是安全声明**；self-modification 的 vm 沙箱也不是。不要把"跑在 worker 里"当成隔离结论。（1.1：PTC 现在在 OS 沙箱下的独立进程里跑，上游仍声明 `process` 描述符不代表多租户隔离。）
- **Agent Teams 是 experimental 私有 opt-in**，`writeScopes` 只是建议性告警而非锁——多 agent 并发写同一片文件仍然需要外部约束（worktree、分支、CI 门禁）。（1.1：仍是 experimental；信箱语义已变，见增量。）
- **文档体量本身是成本**。`docs/` 里的 catalog（tool-catalog 2221 行、module-graph 1691 行、persistence-catalog 1007 行）是生成的，由门禁校验新鲜度。想学它的做法，要连"生成 + 校验"一起学，否则手写目录会立刻腐化。（1.1：分别为 2,824、1,777、9,140 行。）
- 星标增长（两天 9.5 万、一周 16.5 万）是关注度信号，不是工程质量结论；本分析的判断基于源码与文档本身。
- （1.1）默认对外发送的数据比 1.0 时多：`web_fetch` 默认开启且在沙箱与审批之外，发往 DeepSeek 官方 API 的请求默认附带插件清单与 session 日志后缀。事实清单见增量"新增"。

## 0.1 → 0.2.1 增量（2026-10-25 核验）

方法：b150a551 与 1f81c047 两个 commit 都以 shallow boundary 存在于本地 checkout，下列事实来自两棵树的直接比对、对应的 Agent Note 与 upgrade guide，以及 GitHub compare 与 release notes。

**规模**：9,254 个 commit；28 个 release，全部标为 prerelease、没有正式版；`packages/*/*` 227 → 343 个包，其中 experimental 2 → 47；文件 7,903 → 16,347；upgrade guide 0 → 43 份；Agent Notes 中 implemented 560 → 297、archived 143 → 924、proposed 26 → 42；`SESSION_FORMAT_VERSION` 0 → 4。

### 改名

- **Code Mode → PTC（programmatic tool calls）**：`tools.mode: 'code'` → `'ptc'`，`ctx.codeRuntime` → `ctx.ptcRuntime`，`packages/code-runtime/*` → `packages/ptc-runtime/*`，dispatch 事件 `tool/code-dispatch*` → `tool/ptc-dispatch*`，文档 `docs/subsystems/code-runtime.md` → `docs/subsystems/ptc-runtime.md`。上游的理由只是"一个功能两个名字"（客户端 preset 早已叫 "PTC mode"）；不留别名、不提供兼容包或第二个服务注册；模型可见的 `run_code` 及其 `code` 参数保留。持久事件名的改名没有原地做，而是等到 V2 → V3 迁移边一起做——改名也受下文"已发布数据"规则约束。这个名字与 `.planning/freshness-reviews/2026-08-23-source-freshness-review.md` 记录的 OpenAI Agents JS Programmatic Tool Calling 同名；上游没有说明这层关系，"命名收敛"只是推论。
- 字段与配置：compaction 的 `surfaceOp` 用 `startSeq` / `endSeq`；spill 策略用 `maxInlineTokens`；workflow 引擎由 `workflow-worker-thread` 换为 `workflow-ptc`。
- 路径：`docs/defensive-patterns.md` → `docs/defensive-patterns/README.md` + 主题文件；`packages/workflow/tool-ralph/` → `packages/experimental/tool-ralph/`；`docs/subsystems/invariants.md` 无替代。
- 语义未变（个别只换了字段名或位置）的：插件树、profile 与 `--dump-config`；capability seam 三角色；turn / step / round；scope 遮蔽；`ToolGuard`；`deferContext()` / `concludeTurn()`；`saveText()` 的不透明 locator；compaction 锁；workflow `result` 永不 reject。

### 删除（这一轮最有教益的部分）

**1. Runtime invariant 注册表（0.2.1-alpha.1 删除）**

事实（按时间）：

- 2026-07-19 起：`ctx.invariants` 注册表，每个包都必须拥有 `./invariant`；无关系可断言时导出带 `No runtime invariant:` 解释的空 installer——即 1.0 描述并写进 skill 的形态。
- 2026-08-03（b150a551 时已实施）：出厂 TUI / Web 配置不再挂载注册表与任何 companion。理由是同一份诊断让两个产品面失败行为不同——一次关系断言失败就能终止普通的 TUI 运行；session 校验、快照与深冻结作为常开边界留在 `Session` 里，不依赖这个可选服务。
- 2026-08-28：审计删掉 209 个"有解释的空 companion"和一个合成探针，只留 39 个"有独立观测"的检查。被删探针的问题，上游原话是它"mutated and inspected one route table through the implementation it claimed to verify"。新规则：只有能比较**可能各自出错的观测**才发布检查——跨事件的生命周期 / 顺序 / 配对协议、事件对照权威可变状态、多生产者拼装的输出、被另一个操作消费的持久数据；服务或方法是否存在、插件元数据、固定样例、调用同一变更再读回的探针，归类型、加载、单元或集成测试。
- 2026-09-30（f028f256）：连这 39 个也删了，包括 1.0 视为 `model-visible ⟺ logged` 守护者的那个——b150a551 版的 reconstructable-requests note 写明，agent-loop companion 用一个全新的 `Session` 独立重建每个请求再与真实请求比对，是一个真正的独立观测；upgrade guide 显示它到 v0.2.0-rc.2 仍随 `sdk-minimal` 挂载。删除提交更新文档与 README、归档相关 note、新增 `docs/upgrade-guide/v0.2.0-rc.2/remove-runtime-invariants/guide.md`，**没有写说明删除理由的 note**。现在 `2026-07-05-reconstructable-requests.md` 把保证落在三处：请求只能从日志构建（被否决的备选正是事后 detect-and-report）；带 key 的 e2e 要求首个请求之后 cache-read token 为正；生产中每一步的用量就是信号。

本仓库现在应当相信：

- 不变量要有**独立产生的观测**。用同一段代码写入、再经同一段代码读回核对的，是测试，不是不变量；发布一个检查之前，先指出那两个可以各自出错的来源。
- 只在测试或开发组合里运行的"运行时"检查，本质上是多了导出、依赖、构建与门禁成本的测试，不保护生产。生产中必须成立的性质，要么做成构造上无法违反，要么做成 owner 组件里常开的边界，再配一个生产可观测的信号。
- "这里没有可断言的关系"是一句文档，不是一个空 hook。
- 上游为什么连有独立观测的 39 个也删，没有成文理由。推论（待核验）：它们从未进入出厂配置，而 per-file 100% 覆盖率门禁、keyless 录制会话回放与真 API e2e 已经覆盖同一批性质，剩下的只有维护成本。
- `skills/test-ai-agents/SKILL.md` 的 `## Composition and Invariant Tests` 推荐的正是被撤回的形态：在运行时断言权威状态，无可断言时说明理由。要改写的是**检查放在哪里**：skill 举的例子（"模型看到的都在日志里"、"锁最后释放"）本身是对的关系性质，该进测试或构造约束，而不是一个运行时注册表。本仓库自己的 `scripts/check-lab-invariants.sh` 是 CI 里执行的静态门禁，属于上游保留的那一类，不受影响。

**2. Agent Teams 的 durable 信箱（0.2.1-alpha.2 删除）**

事实：新消息直投目标 Agent 的 inbox，`send_message` 只返回 `{ "sent": true }`；接受不代表模型已处理，也不附加同步 flush；失败的发送不留存、不重试，显式重发不去重；`maxPendingMessagesPerMember` 删除；历史 `team/message/queued` / `delivered` 记录仍可回放，但升级前未送达的排队消息永不投递，upgrade guide 要求升级前先排空。理由（`.agents/notes/implemented/simplification/2026-09-26-team-direct-inbox.md`）：Team outbox 与 Agent inbox 重复拥有同一件事——两套 id、两种确认、两套持久化检查点与重试顺序；该 note 写明，只有出现 Agent inbox 承担不了的 durable 发送意图需求时才重新引入。

本仓库现在应当相信："已排队减已送达"仍是正确的 durable 发送意图模式，但只在接收方无法自己承担"接受"时才值得建；接收方 inbox 一旦在接受时就持久化，发送方 outbox 就是同一份所有权的第二个 owner。去掉重试时要把语义写死——无重试、无去重、失败对调用方可见——并写明升级时在途意图如何处理。

**3. 模型可写的自修改工具集（0.1.6-alpha.2 删除）**

事实：release notes 写明 Creator mode 移除 Cordis 动态定义与运行工具，改由 Plugin Manager 安装持久插件。理由（`2026-09-16-creator-persistent-plugin-management.md`）："Generated-code tools create a second plugin lifecycle"。现在模型只有两个只读的 `cordis_inspect_*` 工具；要改运行时，就在工作区写包与 Loader patch，再经 `plugin_manager` 的 `install_bundle` 安装。每个 `plugin_manager` 动作都要求 `danger-full-access` 或该次调用的审批，因为 profile 改动能以宿主权限加载代码并影响其他 session；批准不改变 session 权限，但改动跨 session、跨重启持久，装进来的宿主代码在工作区沙箱之外、进程内运行。历史 session 的旧卡片仍能渲染。

本仓库现在应当相信：1.0 把"动态包只活在内存、不写文件、不跨重启"当成收敛风险的优点；上游的结论相反——临时性不提供安全（安全来自 bash 等价的授权闸，这一点 1.0 写对了），它只是多造了一条生命周期。agent 扩展自己的运行时，应走与人工安装相同的 install / enable / reload 生命周期，在安装处把关，并明说持久、跨 session、以宿主权限运行这三个后果。

**4. "每个非平凡改动必须带 Agent Note"（规则放宽）**

事实：旧规则把"改了行为、架构、跨文件契约、流程、测试策略、磁盘 / 线上 / 配置格式"都算非平凡并强制带 note；新规则只要求记录代码、测试与现有文档解释不了的长期决策理由，机械或局部改动（含局部 UI）豁免，只描述小 UI 调整或纯机械改动的 implemented note 直接删除。`## Alternatives considered` 仍强制，归档即冻结不变。implemented 从 560 篇降到 297 篇，archived 从 143 篇升到 924 篇。

本仓库现在应当相信：按改动强制写 ADR，产出的是数量，不是理由。值得机械化的是"决策必须写出它击败了什么"和"过时即冻结"，不是"每次改动一篇"。`analysis/21-lab-design-rethink-2026-08.md` 把 DeepSeek 的 Agent Notes 门禁列为本仓库该学的机械约束；要学，就学放宽后的版本。

**5. 另两处收窄**

- **`both` 调用形式**（0.2.1-alpha.2）：每个 agent 只能选 `native` 或 `ptc`，配置写 `both` 直接拒绝而不是静默映射。理由（`2026-10-05-native-or-ptc-presentation.md`）：混合形式把同一能力广告两次、多出一种准入组合，却没有带来独立的执行能力；重新引入需要具体需求和证据。
- **Ralph 撤出默认组合**（0.1.6-alpha.1）：默认 session 带着一个自身描述就限定"只在人类明确要求时用"、harness 也不为其完成判定背书的工具，所以改为默认关闭——note 的说法是"opt-in rather than merely discouraged"。同一 note 否决了把 goal 工具一并降级：两者都缺独立评估，但 goal 是唯一受支持的长任务路径。

**共同点（推论）**：四项删除加两处收窄，几乎都在收回"第二个 owner"——旁路检查与测试、Team outbox 与 Agent inbox、生成代码插件与已安装 bundle、逐改动 note 与代码/测试/文档、混合调用形式与单一形式。`packages/AGENTS.md` 的"Require a current owner and need"（每个抽象、状态机、选项、兼容路径都要挂在现有契约或生产消费者上）是这些删除背后的那条规则。

### 加强

**Session log**

- **system prompt 成为 surface 0 号节点 `system/message`**（2026-09-02）：此前 prompt 存在只入日志的 `request/header` 里、由各序列化器前置，"模型看到了什么"要拼两个来源；现在一个模型可见事实只有一个家，prompt 变更是一次 surface 替换，header 只剩 config、adapter defaults 与 tools。
- **request series**：`request/header` 的理由为 `initial` / `resume` / `change` / `series`；series 标出新消息系列的起点（显式声明、surface 替换、插件改写已有消息内容之后），此处写一份完整 header 快照，工具声明从这里重新开始。每个 header 都是自包含的完整快照，只凭一个日志窗口就能重建请求。
- **按 route 选择 prompt 更新方式**：模型 route 声明 `systemPromptUpdate: 'in-history'` 时，变更后的 prompt 追加在已缓存历史之后，前缀缓存保留；否则替换头部，从第一个 token 起失效；所选方式记入 `request/context`。迁移性：这依赖模型侧语义——最新的 system 消息整体替换先前的。1f81c047 只有内置的 `deepseek-flash` 声明了它，所有 `dsh-llm-pi-ai` route 仍替换头部。能迁移的是"按 route 声明能力、并记录所选方式"，不是追加本身。
- **每次模型尝试一条结算事件**（format v2）：成功或带可见内容的取消 → `assistant/message`（内嵌紧凑的带时间戳流）；失败、重试、取消、流错误 → 只入日志的 `assistant/attempt`，不伪造模型历史。代价写在 README 里：结算前的硬性进程丢失不留下任何 durable 流。
- `ctx.sessionProjections` 成为必需接缝，读方缺它时显式失败；`deriveMessages()` 保留；改写已有消息内容的插件必须注册纯函数投影。
- **单写者**：进程内写句柄 claim + 内核锁（`session.lock` 上的非阻塞 `flock`，Windows 用命名信号量）。崩溃的持有者随进程释放；卡死的持有者阻塞写者直到它退出；NFSv3 上的 advisory `flock` 不可靠。
- 格式 0 → 4，V4 至迟随 `dsh-v0.2.0-rc.2` 发布。

**契约演进：从"拒读旧格式"翻转为"已发布数据是义务"**

- 旧：`AGENTS.md` 的 "Pre-release stance: foundation over blast radius"——没有外部消费者，正确的基础优先于兼容垫片，后端拒读旧磁盘格式，`SESSION_FORMAT_VERSION` 停在 0、不做兼容承诺，并注明"第一个 tag 发布时删除本节"。
- 新：触发点是 v0 格式随一个 alpha 发布了（`2026-08-31-released-session-format-migrations.md`）。现在任何 alpha / beta / rc 发布都确立对既有 session 数据的义务，上游原话 "GitHub's prerelease flag does not make persisted user data disposable"。迁移只走相邻的 `vN → vN+1`，写出版本命名的后继文件，已提交的世代永不改名、覆盖或删除；遇到未来版本拒读并提示升级。API 仍是 pre-stable：改名不留别名，所有消费者一起改。
- **每个对外可感知的破坏附一份 upgrade guide**：范围是命令与 profile、`cordis.yml` / settings 键、持久数据、SDK 与 wire、发布包入口。在引入破坏的同一改动里写 `docs/upgrade-guide/v<ver>/<item>/guide.md`——`<ver>` 是写作时的根版本，guide 描述升级到下一个发布；只有 `## Change` 与 `## Migration` 两节，≤500 词，最后一步写如何确认迁移成功；理由不进 guide，进 Agent Note；有门禁。
- 与已有分析的关系（判断）：MCP（`analysis/20-mcp-2026-07-28-revision.md`）对 API 用三态 + 最短 12 个月窗口 + 登记表；本仓库 `skills/build-ai-agents/SKILL.md` 的 Contract Stability 用三态 + 至少两个 MINOR + `弃用登记`。DeepSeek 对 API 走另一端（无弃用窗口、无别名、随时破坏但必附迁移说明），对持久数据则比两者都严。对本地自研 harness，这种按面区分是对的：用户磁盘上的 session 日志从第一个发布构建起就不能作废，内部 API 只要每次破坏都带一份写于改动当下的迁移说明即可。另一条可迁移的事实：首个整文件迁移实现在一个 116 MB 的真实 session 上耗尽了 16 GB 的 Node 进程，上游因此改为有状态的流式迁移阶段——迁移要按真实数据规模设计。

**"结果未知"的工具结果**（崩溃修复部分 b150a551 已有、1.0 漏记；失败 step 与 fork 两处为新增）

- 判据是 durable 开始记录：有 `tool/call` 无结果 → `TOOL_OUTCOME_UNKNOWN`，模型看到的结果写明 "Its outcome is unknown."，只许重试只读或幂等操作，可能有副作用的先核对外部状态或问人；没有 `tool/call` → `TOOL_NOT_STARTED`，仍需要就重试。
- 2026-09-19 起，agent loop 在关闭失败的 step 之前就为每个未答复调用写入这类结果——否则已关闭的错误 turn 在 resume 时修不了，而要求 call/result 配对的 provider 会拒绝之后的每个请求；fork 只按继承的前缀判断。
- 保守边界写得很清楚：开始记录写在调用准备之前，它不证明工具体运行过，所以"未知"保持保守；支持幂等键的 provider 可以拿到稳定的 `callId`，但 harness 不声称通用的 exactly-once。
- 与 `analysis/01-pi-source-analysis.md` 的 effect sandwich 合起来才完整：那边是"先提交意图（幂等键由任务作者写进 intent）、再执行、再提交结果"（Pi 旧版所谓"预铸 id"只是它自己的记录槽位，见 `analysis/01` 2.0），这边是"恢复时看意图记录在不在，决定告诉模型什么"。

**PTC 执行**

- Node PTC 默认每次调用一个全新 Node 进程：经与 Bash 相同的 `ctx.sandbox` 限制，由 `ctx.subprocess` 管生命周期，模型可见的 `process.env` 为空。受限模式下沙箱后端起不来就失败（`sandbox-unavailable`），不退化为无沙箱；文件模式、观测到的拒绝与执行完整度作为 `PtcRunResult.sandbox` 与程序结果分开上报。理由是 worker 只隔离 JS 状态，模型代码能直接 import 文件与子进程 API，绕过工具策略。
- 拒绝或传输失败绝不自动重放一个效果可能已经发生的程序。
- 默认 120 秒、上限 600 秒的墙钟期限包含嵌套工具与审批等待，不是进程树 CPU 预算。
- 可选的进程内保留状态（REPL 式）不持久、重启不恢复；默认仍无状态。Python provider 仍是 experimental。

**其他**：goal 域与 Model Experience 模板的变化已在上文原地标注；`## Known Limitations and Deferred Work` 门禁与 allowlist 未变。defensive patterns 拆成目录后新增的规则里，与本仓库最相关的是"一个值只陈述一个事实"——未知、空、缺省是三个事实，要三种表示，与"结果未知"同源。

### 新增

**实验性 Auto review（`packages/experimental/auto-review/`，默认关闭，只在 Web）**

- 机制：选中后，当前 agent 自己的 provider 与模型在执行前审查每个原生调用和每个已启动的 PTC 内层 `tools.*` 调用。按实际效果而非名称或声称的意图分级：low（项目内读写、测试与构建、清理本 session 创建的对象）放行并以 Full access 执行；medium（删除既有状态、force push、生产操作、对外写入、权限与安全改动）只有当前人类或直接父 agent 明确授权了动作、目标与范围才放行；high（跨信任边界的敏感数据外泄）一律拒绝，即使被明确要求；效果含糊即拒绝。
- 判定上下文：固定策略、只含 cwd 的环境、带来源的项目约束、过滤后的历史（人类与直接父消息、checkpoint、历史调用名与参数）、完整的待决动作；主 agent 的 system 消息、助手文字与推理、工具结果全部排除——与 `analysis/23-claude-code-auto-mode.md` 的 reasoning-blind 同向。
- 失败语义：输出必须是严格 JSON，只接受 `low+allow`、`medium+allow/deny`、`high+deny`；畸形输出或技术失败让调用失败，绝不执行。选中 Auto 即设 `ask` 审批策略，被拒的调用转去问人；进程内委派的子 agent 固定为 `never`，拒绝即终局。无工具豁免、无缓存授权、无重试、策略不可配置。
- 自陈缺口：Auto 不提供文件沙箱；外层 `run_code` 传输与 PTC 程序里的直接 Node 效果不经内层审查；模型分级会错。风险等级与审查轨迹不持久化，只有拒绝原因进日志。
- 判断：(1) 这是"模型审批层必须覆盖每一条有副作用的路径"的实证——审查挂在工具管线上，绕过管线的效果（PTC 程序里的网络与文件 API）既不受审，在 Auto 的 Full access 下也不受文件沙箱约束；上游自己的规则"在做出决定的那个操作里执行决定"（`packages/AGENTS.md`）恰好指向这里。(2) 与 Claude Code 的 deny 预算熔断不同，DeepSeek 把每一次拒绝都交给人，打扰次数随拒绝数线性增长。(3) 放行的调用不留风险等级与理由，事后无法审计"为什么放行"。(4) 上游用真实模型做的认证只有 8 次审查调用，其余靠确定性测试；对一个替代人工审批的分类器，这个样本量只能证明接线正确。

**实验层成为产品政策**

- experimental 包从 2 个到 47 个：其中 9 个是从产品组降级进来的（hooks 三件——两个桥接加协议库、`tool-ralph`、`ptc-runtime-python`、`tool-terminal`、`tool-session-query`、`skill-badge`、`session-title-all-prompts-llm`），2 个原本就在，其余 36 个以实验身份新进。
- 三条独立的轴：Experimental（整体仍在评估、无产品支持承诺、可撤回，但工程、安全、文档、测试与已发布数据的义务照样适用）、Optional（用户显式选择）、Official（项目维护并列在 Plugins 页）；三者都不由"是否默认安装、是否出现在 GUI"决定。晋升要有命名的产品角色、写明的行为与限制、现有消费者、发布内容与测试证据。实验能力以默认关闭的 bundle 随安装分发。
- 判断：这给了"降级"一个正式出口。Ralph 不是被删，而是被移到一个明确不背书的层。

**默认出站数据（事实，不作建议）**

- `web_fetch`：2026-09-01 的决定让共享 base 默认开启它，headless、SDK、ACP 与自定义 base profile 都继承；它在 shell / 文件沙箱与审批预设之外执行，无逐次确认。HTTP provider 逐请求解析并只放行公网地址（含 DNS64 情形）、固定已校验地址、同源重定向重新校验——防 SSRF，不防向公网发送数据。
- 发往 DeepSeek 官方 API 的请求默认带两个扩展字段（经 `baseURL` 选定的网关收到同样的值）：`dsh_plugin_packages`（启用中的插件 npm 包名与版本）和 `dsh_session_log`（canonical session 日志自上次被接受以来的连续后缀，每请求 ≤8 MiB；按文档可含工作目录、system prompt 快照、用户与助手内容、失败尝试的输出、工具参数与结果、compaction 摘要、反馈与插件事件；API key 不在其中）。两个插件都由出厂 base 组合挂载、属于产品组而非 experimental，都可在配置里关闭，session 日志另有 Web 设置开关。
- Web 端对用户消息里识别出的凭据只做**显示**遮罩（保留前 8 个字符），消息文本、复制与模型输入都保留原文。推论：粘贴进对话的密钥照样进入模型请求，并在默认配置下进入上传的日志后缀。
- 新增 `SAFETY.md`：未经安全审计；沙箱、审批与权限控制只降低风险、不保证隔离；建议最小权限、一次性 VM 或容器、备份。

### 更正：1.0 自身的错误与漏记

1. 包数"478"无法复现，已在开头原地更正。
2. 工具管线里 guard 与审批的顺序画反了，已在流水线一节原地更正。
3. runtime invariants 在 b150a551 时已不在出厂配置里；1.0 把它们写成运行时保护。
4. Code Mode 在 b150a551 时有 `'native' | 'code' | 'both'` 三种形式。本仓库 skill 与 `analysis/07-overall-agent-analysis.md` 写的"与原生 tool loop 互斥，否则模型会在两条路径间摇摆"是本仓库的推论；上游当时把按工具分层推迟到"有了 `both` 下模型如何分配用法的证据"之后。上游后来确实删了 `both`，但理由是接口重复，"摇摆"至今没有上游证据。
5. `TOOL_OUTCOME_UNKNOWN` / `TOOL_NOT_STARTED` 的崩溃修复在 b150a551 已存在，1.0 漏记。
6. goal 域自陈的 No independent evaluator 与进程内伪造风险在 b150a551 已存在，1.0 只对 Ralph 记了这一条；于是 `analysis/07-overall-agent-analysis.md` 把 DeepSeek goal 域列为"完成判定必须由执行方之外给出"的独立来源之一——这条归属不成立。
7. `model-visible ⟺ logged` 是单向的（见核心抽象原地更正）；`skills/design-ai-agent/SKILL.md` 写的 "anything logged is model-visible" 是误读。

## 对最终 skill 的影响

### 1.1 本轮（suite 2.3.0）实际落地

- `skills/test-ai-agents/SKILL.md`：改写 `## Composition and Invariant Tests` 的不变量一段——不变量需要两个能各自出错的观测，读回同一代码刚写下的值是测试，不在发布产品里运行的检查是包装过的测试，生产中必须成立的性质靠构造或数据所有者内常开的守卫；不保留空的或"解释为空"的不变量占位。
- `skills/design-ai-agent/SKILL.md`：`## Model-Visible Surface and Authority` 删去"凡记录的都对模型可见"，改为"模型看到的都在日志里"并靠构造成立（每个请求从日志构建）；`## Contract Deprecation` 区分 API 与已发布的持久数据（逐版本迁移、每个破坏附简短迁移说明）；goal 一段注明持久 phase 只分开"轮次结束"与"目标达成"、本身不是独立判定者，人暂停的 goal 只由人恢复；"结果未知"的模型侧结果写入 `## Durable Execution and Side Effects`。
- `skills/design-agent-tools/SKILL.md`：程序化调用一段删去"模型会摇摆"的理由（上游删掉混合模式是因为接口重复），补"程序代码在 OS 隔离进程里运行、崩溃后不自动回放"；默认工具若在描述里劝阻使用，就降到 opt-in 层。
- `skills/secure-ai-agents/SKILL.md`：模型审批层必须覆盖每一条有副作用的路径，覆盖不到的由 OS 级隔离兜底；对子 agent 的拒绝即终局；审查失败即拒绝；自修改工具集一条补"或像上游那样删除它，让 agent 自我扩展走正常的插件安装流程"。
- `skills/review-ai-agents/SKILL.md`：code mode 一项改为"调用方策略缺失或未强制、程序路径的副作用绕过审查"；增加"守卫可被取消选择"。
- `skills/build-ai-agents/references/source-map.md`：改钉 `1f81c047`，替换失效路径，补 `docs/upgrade-guide/` 与 `packages/experimental/auto-review/`。
- `analysis/07-overall-agent-analysis.md`：共识里"完成判定必须由执行方之外给出"一条去掉 DeepSeek goal domain；Code Mode 一条改为按工具声明调用方，并删去"摇摆"理由。

### 1.1 提议但本轮未采纳

- prompt 更新方式按模型 route 声明并记录所选方式（design-ai-agent）：由 design-agent-tools 的"上下文只追加"一节统一表述。
- 拒读未来版本的持久格式、"模型只在本轮有直接人类请求时创建或恢复 goal"（design-ai-agent）：受体积预算限制，留在本文。
- 改用 PTC 名称、失败分类补 `protocol` / `sandbox-unavailable`（design-agent-tools）：skill 保持与厂商无关的措辞；本文与 `analysis/02` 记录了命名。
- "用产生状态的同一路径核验状态""已发布的持久格式变更没有相邻迁移"两条审查项（review）：前者已由 test-ai-agents 的不变量改写覆盖。

### 1.0 条目（已在 `CHANGELOG.md` [2.2.0] 对应提交中落地，1.1 标注其中已被推翻的部分）

- `skills/design-ai-agent/SKILL.md`：新增 capability seam（定义/提供/消费三角色）与"可见性 ≠ 权限"、`model-visible ⟺ logged` 不变量、turn/step/round 三级循环及各自的预算、工具层直接结束当前轮与延后上下文的能力（`concludeTurn` / `deferContext` 的形态）、goal gate 与轮次结束的区分（含持久 phase + revisioned CAS、激活态不持久化）、脚本编排层"模型只给名称与参数、元数据先按纯数据校验"。（1.1：不变量的方向与落实方式见上。）
- `skills/design-agent-tools/SKILL.md`：新增 `## Prompt Prefix Economics`（确定性工具排序与前缀清单）、`## Document What the Model Sees`（模型看到什么 / token 效应 / prompt-cache 效应 + 已知限制，并建议机械化检查）、spill 到不透明 locator（best-effort，失败不得把成功变成错误）、compaction 前先做 tool-result pruning、用锁包住整个 compaction 操作并以显式 surface 操作表达替换、structured handoff 必须有显式上限，以及 Code Mode 作为可选的工具传输层（与原生 tool loop 互斥、`isolation` 不是安全承诺）。（1.1：Code Mode 改称 PTC，互斥的理由需更正。）
- `skills/secure-ai-agents/SKILL.md`：新增 `## Authority Boundary Design`（单调 guard——类型上无 allow 返回值；闭合审批四元组且 unavailable ≠ allowed；授权不从序列化状态继承）与 `## Sandbox and Subprocess Hygiene`（按调用解析沙箱策略、denial 与 runner failure 分离且都不得回退到无沙箱、正交结果独立上报、spawn 时按白名单构造环境、私有目录 + 排他创建、link 形状路径按链接删除、命名 preset 与派生 custom、可自我修改的工具集按 bash 等价对待）。（1.1：上游已删除该自修改工具集，见上。）
- `skills/test-ai-agents/SKILL.md`：新增 `## Composition and Invariant Tests`——走真实配置与入口的 real-composition 测试、runtime invariant 只断言权威事件流/可变数据（不断言服务存在，且空实现必须说明理由）、assembled transcript 的稳定键快照、disposal / 热重载必须到达静默态。（1.1：runtime invariant 一段的形态已被上游撤回，见上；其余三项仍成立。）
- `skills/review-ai-agents/SKILL.md`：审查面增加 guard 可被重排打开、授权从序列化状态恢复、工具列表顺序不稳定导致 prompt cache 失效、轮次结束被当作目标达成、code mode 与原生工具调用同时开启、沙箱 `isolation` 标签被当作安全边界。
- `skills/implement-ts-agents/SKILL.md`：新增 `## Plugin-Tree Runtime`，把插件树 / 接缝形态列为自研 TS runtime 的一种可选骨架，并写明它的代价与不适用条件。
- `skills/build-ai-agents/references/source-map.md`：登记 DeepSeek Harness commit 与高价值文档/包路径。（1.1：其中两条路径已失效，见上。）
- `analysis/07-overall-agent-analysis.md`：共识矩阵新增 2026-08 刷新列与四行新维度（KV cache 前缀经济学、持久化执行与副作用治理、完成判定归属、契约演进政策），形态光谱加入插件树 harness 与 Code Mode。
