# DeepSeek Harness 插件化 Agent Runtime 分析

> 分析版本：1.0 ｜ 最后更新：2026-08-23 ｜ 来源：DeepSeek AI, deepseek-harness（commit `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e`，版本 `dsh` 0.1.1-rc.2，详见 `analysis/SOURCE_INDEX.md`）

DeepSeek Harness（`dsh`）2026-08-13 开源，是 DeepSeek 官方的 agent harness，MIT 许可，TypeScript 单仓 478 个 workspace 包，构建在 vendored 的 [Cordis](https://github.com/cordiverse/cordis) 微内核之上，口号是 **"Everything is a Plugin"**：模型适配器、工具注册表、session log、agent loop 本身都是插件，都能从配置替换，没有一个"特权内核"可打补丁。

它对本仓库的价值不在于"又一个 coding agent"，而在于两点其他来源都没有同时做到的事：

1. **它把 harness 拆成了可命名、可替换、可核验的接缝（capability seam），并逐子系统写下了契约级文档**。`analysis/16-openai-codex-harness.md` 展示了生产 harness 的边界，但 Codex 是 Rust 单体；`analysis/10-learn-claude-code.md` 展示了机制的最小骨架，但是教学实现。DeepSeek Harness 第一次让"生产强度 + 明确接缝 + 公开契约"三者同时可读。
2. **它把"模型看到什么"变成了一等工程对象**。仓库强制每个包的 README 写出 Model Experience（模型看到什么 / token 效应 / KV-cache 效应），并用脚本门禁检查。这把 `analysis/08-anthropic-writing-effective-tools.md` 的 token 效率原则升级成了组织级的、机械可检的约束，并补上了本仓库此前完全缺失的一个维度：**KV-cache 经济学**。

它同时处于 developer preview，README 明确写着"会有破坏性变更"。本分析吸收其结构与契约，不把版本级 API 当作稳定引用。

## 核心抽象

- **Cordis 插件树 + profile/bundle 分层组装**。运行中的 `dsh` 是一棵 boot 时按顺序层叠出来的插件树：`bundle`（一组 Cordis 配置行 + 它挂载的代码）→ `profile`（命名组合，如 `web` / `headless`）→ profile 自身 `cordis.patch.yml` → home 级 patch → `--patch` 覆盖层。每一层都能按 id 定位并替换上一层插入的行。`dsh --profile web --dump-config` 打印真实启动的树，任何一行都能被自己的 patch 替换。这是"配置即组装"的彻底形态：扩展方式是"在旁边挂一个插件"，不是"改内核"。
- **Capability seam = Service Definition + Service Provider + Consumer 三角色**。一个"可替换能力"必须同时设计三个角色：声明接口与词汇的 Service Definition（拥有 `ctx.<key>`）、实现它的 Provider、使用它的 Consumer（通常是面向模型的工具）。`packages/shell` 是范式：`dsh-shell`（定义）/ `dsh-bash-local`、`dsh-bash-sandbox`（提供者）/ `dsh-tool-bash`（消费者）。仓库明确规定：**seam 是完整的能力，绝不用这个词指其中一个角色**。这个纪律的收益是"换一个 provider 就换掉整个产品面"——filesystem 与 subprocess 提供者共享同一个执行世界，把它们指向远程沙箱，Bash、PTY、LSP 一起搬走，不需要为任何 provider 开分叉。
- **Event-sourced session log 是唯一真相源**。session 是一条只追加的 `SessionEvent` 日志；模型历史是从日志 `deriveMessages()` **投影**出来的，不单独存储。原始 `assistant/chunk` 保留用于回放与 UI 保真。fork、resume、transcript、telemetry、持久化全部从这条流派生。
- **`model-visible ⟺ logged` 不变量**。任何进入模型请求的东西都必须能从 session log 重建，并且有一个 runtime invariant 在断言它。因此"新增一种模型可见输入"这件事的工程含义是"新增一个 session event 类型并从日志渲染"，而不是"在 prompt 组装里加一行"。
- **turn / step / round 三级循环**。step = 一次模型请求加上它引发的工具执行；turn = 零个或多个 step，从第一份输入被 claim 时开启，到"无债可还"时关闭；round = 包住一个 turn 的**外层策略迭代**（goal round、Ralph round）。round 计数属于那条策略，不统计 session 里的每个 turn。本仓库此前只有 turn/step 两级，缺了策略层。
- **agent scope：两层、扁平、most-specific-wins**。一个贡献（工具、prompt section、变量、限制、监听器）要么全局，要么属于恰好一个 scope key（约定就是那个 live `Agent` 对象本身）。scoped 注册**不向 subagent 继承**；子树行为用 lineage 数据（`parentSession`、`delegationDepth`）表达，绝不用 scope 结构表达。同名 scoped 工具遮蔽全局同名工具（per-agent persona 与 per-agent 工具变体就是这么来的）。
- **插件而非改 loop**。新行为挂到有文档的扩展点上；要改 `agent-loop` 本身，必须同时更新 `docs/architecture.md`。架构文档里有一张"目标 → 机制"表，把二十多种常见扩展需求映射到具体扩展点。

## 重要模式

### 事件分三域，先选域再写代码

架构文档把"选对事件域"称为大多数改动的第一个决策：

- **Session events**（`turn/*`、`step/*`、`user/message`、`assistant/*`、`tool/*`）：追加到日志、必须在重载后仍然存在的**持久事实**。
- **Agent events**（`agent/pre-step`、`agent/request`、`agent/status`、`agent/turn-stopping`、`agent/request-error`）：携带活的 `Agent`，用于观察或拦截**进行中**的工作。
- **Capability events**（`fs/*`、`tools/*`、`telemetry/*`）：把策略和适配器挂到某个接缝上，**不需要 import loop**。

`agent/pre-step`、`agent/request`、`llm/stream` 和三个 `tools/*` 是 waterfall：监听器**必须调用 `next()`** 才委托下去，不调用就短路整条链。`agent/turn-stopping` 是 serial，没有 `next()`。

### `agent/pre-step`：决定"模型这一步看到什么"的唯一串行点

pre-step 收到独占的 claimed 批次（消息 + turn/step 坐标 + 取消 signal），返回 `reject`（不开 step）或 `enter(messages)`（用这批完整消息进入 step）。被 reject 或首次 claim 被改写为空，仍然会**关闭一个没有花费任何 step 的持久 turn**——日志记录了这次尝试。这是"拒绝也要留痕"的干净做法。

plan mode、workspace instructions（`AGENTS.md` 链）、skill catalog、session reference、time/tmux context 全部在这里落地，彼此不需要知道对方存在。

### 工具执行流水线：可扩展 waterfall + 单调 guard

```
tools/pre-execute (waterfall，可重排：hooks / permission / sandbox)
  → 已注册的 monotonic guards（只能 deny 或弃权）
  → ctx.approval 一次性提示（缺席或无法回答 = deny）
  → tools/execute (around-dispatch：timeout / retry / metrics)
  → 工具体 execute()
  → fs/write-intent | fs/edit-intent（仅 tool-fs 变更）
  → tools/post-execute (accept / block / replace / 追加 context)
  → 注册表外层归一化（快照抛出 → isError）
  → ToolDefinition.finalizeContent（最后的 content-only 不变量）
  → tools/result（同步通知，冻结的权威结果）
```

其中最值得偷的是 **`ToolGuard` 的返回类型故意没有 allow**：`undefined` 保留 waterfall 的决定，返回一个原因就是拒绝。因为 guard 没有"放行"结果，**监听器顺序无法把拒绝变回许可**。这是一个用类型系统表达的安全不变量，比"注意注册顺序"这类文档约定强得多。

配套的还有：`ApprovalOutcome` 是封闭四元组 `allowed-once | rejected | cancelled | unavailable`，调用方只在 `allowed-once` 时放行；缺失、不拥有、抛出或不符合契约的 answerer 都归一化成 `unavailable` 而不是打开闸门。session 级 `approval/policy` 的 `never` 在 waterfall 分发**之前**执行，所以后注册的 `prepend` answerer 也绕不过去。

### Code Mode：把工具调用换成写程序

`ctx.codeRuntime` 让模型写一段程序，宿主把工具作为一个 binding namespace（`tools`）注入为 program 全局对象。参数与返回必须是无损 JSON；运行时把被拒绝的调用变成注入的错误类实例。失败分类是**正交独立上报**的：`exception` / `timeout` / `abort` / `worker-exit` / `invalid-output` / `output-limit`——预算到期不是异常，abort 不是 timeout，底座死亡（OOM）两者都不是。

安全上有一条关键规则：在 `mode: 'code'` 下，只有**带 parent token 的子调度**才能执行原生工具名；模型直发的调用（无 parent）在进入策略流水线之前就被判为 `UNKNOWN_TOOL`。`isolation` 字段（`worker-thread` / `process` / `container`）被明确标注为**诊断标签，不是安全声明**。

### Spill：大输出落盘 + 不透明 locator + 检索提示

`ctx.spillStore.saveText()` 把超限的工具文本原样持久化，返回 `{ locator, bytes, retrievalHint }`。locator 是 branded 的**不透明**模型可见句柄——本地后端渲染成路径，远程后端可以是 URI 或 key，消费者用 `retrievalHint` 渲染而不是假设 `read` 总是正确的取回方式。策略消费者用 head/tail 预览 + spill 引用替换过大的行内结果，并且是 **best-effort**：保存失败保留原始行内结果，绝不把一次成功的调用变成 `isError`。

本地后端的写法本身就是一份安全模板：私有 0700 根目录、`sha256(sessionId)` 子目录、`open(path, 'wx', 0o600)` 独占写，使被植入的符号链接无法重定向。

### Compaction：锁包住整个操作，pruning 先于 summary

`compaction/start` → 摘要 → `compaction/summary` → 替换用的 `user/message`（带 `surfaceOp: { op: 'replace', start, end }`）→ `compaction/end`。**锁最后释放**，所以中途崩溃留下的是一个可检测的孤儿锁（有 start 无 end），而不是一个谎称"压缩完成"的 end。

压力触发时，`compaction-basic` 会先调用可选的 `ctx.toolResultPruner` 做**工具结果剪枝**并用 `ctx.tokenMeter` 重新计量——**能靠剪枝把 surface 推进就不做摘要**。这比"直接上 LLM summary"便宜得多，与 `analysis/10-learn-claude-code.md` 的 cheap-first 分层压缩相互印证。区域边界保留 tool-call/result 配对但不保留整个 turn，所以一个超大 turn 的早期已关闭 step 可以被单独压缩。

失败的模型请求走 `agent/request-error`：只有当 surface 替换代数确实推进了才返回 retry，取消永远优先。

### Token meter：区分"provider 权威用量"与"启发式估算"

`ctx.tokenMeter.measure()` 返回一个脱离引用的不可变快照，含 `baseline.kind`：`usage` 表示最近一次成功调用的规范请求信封相同且总量不低于该次的完整启发式锚点；`estimated` 表示没有可复用的保守锚点，于是整包重新按固定启发式计价。`surfaceDeltaTokens` 是**有符号**的，同时保留增长与收缩。把"我以为的 token 数"和"provider 说的 token 数"分开命名，是很多自研 harness 缺失的一步。

### Goal 域：把"目标"做成 session 内的持久状态，而不是另一个 loop

`goal` 是挂在既有 session 上的一个持久完成目标：`active` / `paused` / `blocked` / `complete` 相位、带修订号的 compare-and-set 变更、goal-round 上限、`blocked` 携带机器可路由的 kebab-case `code` + 人类可读 `message`。关键设计：

- **相位是持久的，激活是进程本地的**。`GoalActivation`（`armed` / `disarmed`）**故意不进入持久回放**，所以 resume 和 fork 之后必须经过一次人类授权的 resume 变更，才能重新开始自动工作。这是一条很聪明的"重启不自动续跑"安全阀。
- goal 是状态，不是调度器，也不是另一段会话；session log 仍是真相源。
- 同一 session 里无关的人类 turn **不消耗** goal-round 配额。

### Ralph：fresh-agent 循环作为一个普通插件

`ralph({ objective, maxRounds? })` 把一个不可变目标交给一串**全新的**子 agent：每一轮起一个 fresh child，child 只收到不可变目标、当前轮次与上限、"共享工作区即权威"的指令，以及上一轮的结构化 handoff。父会话不注入，前一个 child 的会话也不注入。handoff 是归一化的有界结构化报告（`status: continue | complete | blocked` + summary + evidence + next steps + blocker），有显式的 `maxHandoffChars` 上限；无效、缺失或超限的报告**让整个 workflow 失败**，而不是被截断或被误当成配额耗尽。

它的自我限制写得比能力还清楚：**完成是 worker 的自我声明，没有独立评估者**；只有前台；工作区是唯一的跨轮长期记忆；一轮就是一个 fresh child，没有轮内 fan-out；普通 child 失败即终止整个 run，不重试；只有轮数约束总投入，token / 价格 / 墙钟预算是 deferred。

值得注意的是它在架构上的位置：**没有为 Ralph 在 `agent-loop` 里加任何模式**，它只是 `ctx.workflowEngine` + `ctx.subagents` 上的一个普通插件，同 session 的 goal 域完全独立。

### Workflow：模型写编排脚本，引擎跑子 agent

`ctx.workflowEngine` 让 agent 运行一段模型写的编排**脚本**来启动子 agent。`meta` 和 `args` 是纯 JSON 数据，引擎在**任何脚本文本被求值之前**按 schema 校验并大声拒绝。`parallel()` / `pipeline()` 组合子对 `fatal` 错误（拼错的选项、越界的 schema、触发的上限）**重新抛出**而不是把该项映射成 `null`——per-item `null` 只保留给真正的 child 运行失败。`workflow/*` 事件是只观察的数据快照，携带 `WorkflowRunInfo` 而非活的 `WorkflowRun`，订阅者拿不到 `cancel`/`dispose`；每个监听器拿到自己的 payload 克隆，抛出被容纳并记录。

`WorkflowRun.result` **永不 reject**：脚本失败解析为 `stopReason: 'error'`；一旦取消，即使脚本自己永不结束，引擎也会在有界宽限期内强制结算 `cancelled`。等待 `result` 的消费者永远不会被卡死。

### Agent Teams（experimental）：durable roster + mailbox + task DAG

`ctx.agentTeams` 是私有 opt-in 的协调接缝：持久花名册、任务板、信箱，层叠在可续聊的 subagent 之上。信箱的可靠性设计值得记：**Lead session 先存下完整的排队消息，只有当目标方的 pending inbox item 或 user message 已经持久化之后才确认送达**，"已排队减去已送达"就是恢复用的信箱。任务 DAG 的 `writeScopes` 是**归一化的建议性路径前缀，不是锁**——只产生重叠告警，不做互斥。

### Self-referential 工具集：agent 修改自己的运行时

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

### Runtime invariants：断言权威关系，而不是断言存在性

`ctx.invariants.register(packageName, installer)` 是包自有的运行时不变量注册表。约定极其克制：**只能断言权威事件流或可变数据的关系**，不能断言"某个服务存在"、"某个方法存在"、插件元数据或固定的纯函数样例。没有可断言的关系时，正确做法是导出一个**空 installer 并用 `No runtime invariant:` 开头解释为什么这个包没什么可查**——机械门禁会拒绝生成式的占位、没有解释的空实现和忽略 reporter 的实现。

### Agent Notes：机械门禁化的 ADR

`.agents/notes/{proposed|implemented|rejected}/{class}/yyyy-mm-dd-topic.md`，路径编码生命周期与类别；`## Alternatives considered` 是**强制**章节（"记录一个决定却不记录它击败了什么，就是在邀请重新争论"）；implemented note 必须**随代码保持当前**（文件搬了、包改名了、默认值变了，要在同一次改动里更新事实）；proposal 期的标题（`## Proposal` / `## Migration plan` / `## Acceptance criteria`）在 implemented note 里**被门禁拒绝**；归档后的 note 永久冻结，不得编辑、翻译、重排或当作现状权威。**非平凡改动必须在同一个 PR 里带一个 Agent Note**。

这是 `analysis/14-openai-harness-engineering.md` 的 "repository as system of record" 落到可执行门禁的具体形态。

### Defensive patterns：把出过的 bug 类写成规则

`docs/defensive-patterns.md` 每一条都是真实出过或差点出的缺陷类，直接写成防止复发的规则。最通用的几条：

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
- **`model-visible ⟺ logged` 值得作为自研 harness 的第一条不变量**。它同时买到：可回放、可审计、可 fork、可从崩溃恢复、可做 eval 归因。代价是"新增模型可见输入"变贵——这个代价是对的。
- **turn 结束 ≠ 目标完成**。把 goal / round 做成 turn 之上的独立策略层，并且**让激活状态不持久化**，是长任务 agent 的一个安全默认：进程重启后不会自己接着跑。
- **Ralph 式 fresh-agent 循环应该是插件，不是 loop 模式**。它证明了"每轮全新上下文 + 共享工作区 + 有界结构化 handoff"可以完全在既有 subagent/workflow 原语上组合出来。同时它自陈的限制（完成靠自我声明）恰好是 `analysis/19-anthropic-harness-design-long-running-apps.md` 补上的那块——两者合起来才是完整方案。
- **给每一个进入 prompt 的贡献写 token 效应和 KV-cache 效应**。哪怕不引入门禁脚本，把这三个小标题加进内部包/模块文档，就能在设计期而不是账单期发现"这个功能每一步都在动前缀"。
- **区分"provider 权威用量"和"本地启发式估算"**，并让 delta 有符号。否则压缩策略会基于错误的数字触发。
- **正交失败独立上报**是可以立刻用在任何 subprocess / 工具执行层的规则：`timedOut`、`signal`、`exitCode`、`denied`、`runnerFailed` 各自成立，不要互相嵌套。
- **把"这个包目前做不到什么"写进 README 并做门禁**。它让消费者不必读源码就知道边界，也让 deferred work 不会假装成 bug。

## 适用场景

- 需要一个可以整体替换模型 / 工具 / 沙箱 / 存储 / UI 的**产品化 agent runtime**，而不是一个固定形态的 CLI。
- 需要多形态部署（Web、headless、one-shot、ACP、JSON-RPC、SDK）共享同一套能力与日志语义。
- 需要把"agent 能不能修改自己的运行时"作为一等能力，并且愿意为此接受 bash 级别的信任面。
- 需要对模型可见上下文做严格审计、回放和成本归因的团队。
- **不适合**：只需要一次工具循环的小功能；不愿承担 478 包 monorepo 与 Cordis 心智模型的团队；需要立刻稳定 API 的生产集成（developer preview，明示会破坏兼容）。

## 注意

- **Developer preview**。版本 `0.1.1-rc.2`，README 与 `AGENTS.md` 都写明会有破坏性变更，`SESSION_FORMAT_VERSION` 保持在 `0` 且不做兼容承诺，后端拒绝旧的磁盘格式。任何"照抄 API"的做法都会很快失效；应该抄的是结构与不变量。
- **Cordis 是被 vendored 并 rescope 到 `@deepseek-ai/*` 的**（`cordis` → `@deepseek-ai/cordis` 等 9 个包）。它同时说明了一个现实约束：把框架作为 peerDependency 的产品，发布自己就等于发布这一层，用上游名字发布等于在 registry 上占坑。这是供应链层面的真实取舍，不是纯技术洁癖。
- **`isolation: 'worker-thread' | 'process' | 'container'` 明确不是安全声明**；self-modification 的 vm 沙箱也不是。不要把"跑在 worker 里"当成隔离结论。
- **Agent Teams 是 experimental 私有 opt-in**，`writeScopes` 只是建议性告警而非锁——多 agent 并发写同一片文件仍然需要外部约束（worktree、分支、CI 门禁）。
- **文档体量本身是成本**。`docs/` 里的 catalog（tool-catalog 2221 行、module-graph 1691 行、persistence-catalog 1007 行）是生成的，由门禁校验新鲜度。想学它的做法，要连"生成 + 校验"一起学，否则手写目录会立刻腐化。
- 星标增长（两天 9.5 万、一周 16.5 万）是关注度信号，不是工程质量结论；本分析的判断基于源码与文档本身。

## 对最终 skill 的影响

> 下列条目已在 `CHANGELOG.md` [2.2.0] 对应的提交中落地。

- `skills/design-ai-agent/SKILL.md`：新增 capability seam（定义/提供/消费三角色）与"可见性 ≠ 权限"、`model-visible ⟺ logged` 不变量、turn/step/round 三级循环及各自的预算、工具层直接结束当前轮与延后上下文的能力（`concludeTurn` / `deferContext` 的形态）、goal gate 与轮次结束的区分（含持久 phase + revisioned CAS、激活态不持久化）、脚本编排层"模型只给名称与参数、元数据先按纯数据校验"。
- `skills/design-agent-tools/SKILL.md`：新增 `## Prompt Prefix Economics`（确定性工具排序与前缀清单）、`## Document What the Model Sees`（模型看到什么 / token 效应 / prompt-cache 效应 + 已知限制，并建议机械化检查）、spill 到不透明 locator（best-effort，失败不得把成功变成错误）、compaction 前先做 tool-result pruning、用锁包住整个 compaction 操作并以显式 surface 操作表达替换、structured handoff 必须有显式上限，以及 Code Mode 作为可选的工具传输层（与原生 tool loop 互斥、`isolation` 不是安全承诺）。
- `skills/secure-ai-agents/SKILL.md`：新增 `## Authority Boundary Design`（单调 guard——类型上无 allow 返回值；闭合审批四元组且 unavailable ≠ allowed；授权不从序列化状态继承）与 `## Sandbox and Subprocess Hygiene`（按调用解析沙箱策略、denial 与 runner failure 分离且都不得回退到无沙箱、正交结果独立上报、spawn 时按白名单构造环境、私有目录 + 排他创建、link 形状路径按链接删除、命名 preset 与派生 custom、可自我修改的工具集按 bash 等价对待）。
- `skills/test-ai-agents/SKILL.md`：新增 `## Composition and Invariant Tests`——走真实配置与入口的 real-composition 测试、runtime invariant 只断言权威事件流/可变数据（不断言服务存在，且空实现必须说明理由）、assembled transcript 的稳定键快照、disposal / 热重载必须到达静默态。
- `skills/review-ai-agents/SKILL.md`：审查面增加 guard 可被重排打开、授权从序列化状态恢复、工具列表顺序不稳定导致 prompt cache 失效、轮次结束被当作目标达成、code mode 与原生工具调用同时开启、沙箱 `isolation` 标签被当作安全边界。
- `skills/implement-ts-agents/SKILL.md`：新增 `## Plugin-Tree Runtime`，把插件树 / 接缝形态列为自研 TS runtime 的一种可选骨架，并写明它的代价与不适用条件。
- `skills/build-ai-agents/references/source-map.md`：登记 DeepSeek Harness commit 与高价值文档/包路径。
- `analysis/07-overall-agent-analysis.md`：共识矩阵新增 2026-08 刷新列与四行新维度（KV cache 前缀经济学、持久化执行与副作用治理、完成判定归属、契约演进政策），形态光谱加入插件树 harness 与 Code Mode。
