# Claude Agent SDK 分析：把闭源 Claude Code harness 当库托管时，宿主拿到的契约

> 分析版本：1.0 ｜ 最后更新：2026-10-25 ｜ 来源：Anthropic, claude-agent-sdk-python（commit `0e89b298e771259378a6cd3734e00d323dff5703`，v0.2.174，捆绑 Claude Code CLI 2.1.310，详见 `analysis/SOURCE_INDEX.md`）

Claude Agent SDK 是"Claude Code as a library"：同一套内置工具、agent loop、compaction、hooks、子 agent、权限与会话，由**你自己的进程**托管（本文只讨论这种本地 / 自托管形态；Anthropic 托管的部署形态按本仓库 scope 不在讨论内）。它与本仓库已有的两个来源正好互补：`analysis/10-learn-claude-code.md` 是对 Claude Code 机制的教学复述，作者自己声明"是 paraphrase 而不是 ground truth"；`analysis/16-openai-codex-harness.md` 是另一家厂商的本地 harness，Rust 源码全开。Agent SDK 恰在两者之间：**核心闭源**（TS 仓库没有源码，捆绑的 CLI 受商业条款约束），开放的只有 MIT 许可的 Python 包装层、它的类型与测试、两份 CHANGELOG，以及一套写得极细的官方文档（快照 `raw/docs/claude-agent-sdk.md`）。所以本文读的不是实现，而是**厂商给宿主的契约**——权限求值序、hook 的无回答语义、compaction 后各类上下文的去向、resume 时恢复什么、预算覆盖到哪里。`analysis/23-claude-code-auto-mode.md` 讲的是 auto 模式分类器怎么设计；本文补的是它怎样嵌进一条确定的求值序、何时熔断、按什么模型门控。

它对本仓库有三点直接价值。第一，一条精确成文的权限求值序加一组谁都批不了的地板，可以拿来逐条对照 `skills/secure-ai-agents/SKILL.md` 的"单调拒绝"和"闭合审批集"——结果是两者大体成立，但厂商文档自己承认了两个缺口。第二，厂商把"约束不能穿过有损摘要"落成了一张 compaction 生存表，并在 auto 模式文档里直说：会话里口头陈述的边界会随 compaction 丢失，要硬保证就写 deny 规则。第三，TS CHANGELOG 记录了厂商**按模型 ID 退役补偿弱模型的部件**（v0.3.233 → v0.3.268），是 `analysis/19-anthropic-harness-design-long-running-apps.md`"harness 组件是有保质期的假设"最直接的一手证据。凡涉及闭源核心的行为陈述，事实层级都是"文档如此声明"，只有 Python 包装层代码和 `e2e-tests/` 触及之处才算代码核验。

## 核心抽象

- **库 = 闭源 harness 进程的宿主端**。`query()` 起一个 `claude` 子进程（stdio、stream-json），包装层只实现控制协议的宿主一侧：`can_use_tool`、`hook_callback`、`mcp_message` 三类控制请求（`raw/repos/claude-agent-sdk-python/src/claude_agent_sdk/_internal/query.py`）。循环、工具、compaction、权限评估都在二进制里。因此有**两条版本轴**：SDK 版本（0.2.174）与被捆绑的 harness 版本（CLI 2.1.310，记在 `src/claude_agent_sdk/_cli_version.py`）；文档里几乎每条行为都挂着"requires Claude Code v2.1.xxx"。
- **权限 = 固定的六步求值序 + 不可批准的地板**。授权来源分三层：代码选项（`allowed_tools`、`disallowed_tools`、`permission_mode`、`can_use_tool`、hooks）、settings 文件（managed 最高，任一层 deny 不可被他层 allow 推翻）、运行时回调。`allowed_tools` 是**自动批准表，不是可用表**。
- **上下文 = 带生存类别的来源集合**。每类来源在 compaction 后要么从源头重新注入，要么随对话被摘要，要么被重建；system prompt 在会话首个请求时快照化，之后的变化只能作为对话里追加的事实进入。
- **会话 = 对话 transcript，不是文件系统**。持久化是本地 JSONL 加可选的 `SessionStore` 镜像；resume 时权限上下文由新进程的选项**重新推导**，而不是从 transcript 读出。
- **预算 = turns / 估算美元 / 子 agent 深度 / 并发**，覆盖整棵子 agent 树；墙钟缺席。

## 重要模式

### 权限求值序（精确列表）

```
0  可见性裁剪：裸名 deny（Bash、"*"、"mcp__*"）、tools 选项、子 agent 的 tools 子集 → 工具不进请求
1  PreToolUse hooks：并发分发，聚合优先级 deny > defer > ask > allow；退出码 2 在规则之前阻断
     hook deny：任何模式下都是终局（含 bypassPermissions）
     hook allow：只免掉"提示"，不跳过 2、3；批不了关键路径删除与网络路径读；plan 下对写操作无效
2  deny 规则（disallowed_tools + 各层 settings）：命中即阻断，bypass 下亦然
3  ask 规则 + 需要用户交互的工具（AskUserQuestion、_meta["anthropic/requiresUserInteraction"]）
     → 一律交回调，bypass 下亦然；dontAsk 下改为拒绝
4  权限模式：bypass 批准余下一切（地板除外）；acceptEdits 批准范围内文件操作；
     plan 把编辑与写文件的 shell 命令送回调、无视 allow 规则；其余模式落到下一步
5  allow 规则（allowed_tools + settings）+ 工具自有的免批准（工作目录内读、只读 Bash）
6  canUseTool：default 无回调 = 拒绝；dontAsk 跳过本步 = 拒绝
地板：关键路径 rm/rmdir、网络路径读、requiresUserInteraction、显式 ask 规则在任何模式下都不被自动批准；
      protected paths（.git、.claude、shell rc、包管理器配置、.mcp.json 等）只有 bypass 能写
```

出处是 SDK permissions 页的六步说明，地板与 protected paths 来自 Claude Code 的 permission-modes 页（`raw/docs/claude-agent-sdk.md` §3.1–3.3）。auto 模式是在第 4 步把"其余"交给分类器，本地决策序为：规则先决 → 只读与工作目录内编辑自动批准 → 分类器 → 拒绝理由（通常是规则名）回给模型。这与 `analysis/23-claude-code-auto-mode.md` 的 Tier 1/2/3 一一对应，并补上文章没写的几处：protected path 写入即使命中 allow 规则也送分类器；分类器无判决即拒绝；连续 3 次或累计 20 次阻断熔断回人工且**阈值不可配置**；检查进行中切换模式时丢弃新模式本不会请求的判决；会话中切到 auto 不支持的模型会降为 `default` 且切回模型也不自动恢复。

两个容易被误用的事实值得单列。**被提前自动批准的调用永远到不了 `canUseTool`**——放在回调里的检查会被 allow 规则、`acceptEdits` 或 bypass 静默跳过，厂商的对策只是告警（TS `CLAUDE_SDK_CAN_USE_TOOL_SHADOWED`、Python `CanUseToolShadowedWarning`），并建议把必检逻辑放 PreToolUse。**`allowed_tools` 不约束 bypass**：`allowed_tools=["Read"]` 加 bypass 仍会批准 `Bash`。判断：这是"审批点放错层"的典型形态——必检逻辑必须放在求值序最前面那一层，而不是最后才被问的那一层。

### 对照"单调拒绝"与"闭合审批集"

1. **单调性的第二种实现：allow 可表达，但永远被支配**（事实 + 判断）。SDK 的 hook 和回调都能返回 allow，不满足"guard 类型里没有 allow"。它靠四件事保住单调：所有 deny 来源排在任何 allow 来源之前；并发 hook 的聚合是固定优先级，与注册顺序无关——**并发分发反过来逼出了顺序无关的合并**（Python v0.2.82 专门在文档里澄清 hooks 并发执行，不得依赖顺序）；hook 的 allow 只免提示、不越过 deny 与 ask 规则；再加一组谁都批不了的地板。判断：比 DeepSeek 的 `ToolGuard`（`analysis/18-deepseek-harness.md`）弱，但更实用——允许"早放行"以省掉提示，同时把放行的效力限定为"免提示"而非"免规则"。可作为 lab 规则的第二种合规形态。
2. **厂商承认的缺口：单调性随凭证类型而变**（事实）。插件里的 mod 处理 `tool.check` 事件，其 hooks 在 `-p` 与 Agent SDK 中运行。机器上没有 managed settings、会话凭证也不是 Team/Enterprise 登录时——用 API key 跑 SDK 恰好就是这种情况——mod 可以批准被 deny 规则拒绝或被 PreToolUse hook 阻断的调用，回调也不会被问。有 managed settings 或组织登录时这条路默认关闭。判断：一个随部署方式成立或失效的不变量不是不变量。lab 规则需要补一句：单调拒绝要对**所有**能给出 allow 的主体成立，包括宿主加载的扩展代码，且不依赖凭证类型。
3. **闭合审批集：结果类型是二元的，"不可用"散在各条分支里**（事实 + 判断）。`PermissionResult` 只有 `PermissionResultAllow` / `PermissionResultDeny`（后者带 `interrupt` 标志），没有一等的 cancelled / unavailable。但每条"无回答"路径都被定义为拒绝：default 无回调；`dontAsk`；PreToolUse 超时；`PreModelSwitch` 超时（文档的意思是：没回答就没批准）；无法提示的会话里 `PermissionRequest` 无决定；分类器无判决；`requiresUserInteraction` 工具经 `--permission-prompt-tool` 得到的 allow 被改写为 deny（批准必须来自真人）。判断：语义上覆盖了 lab 的四元组，但分散在实现和文档里，宿主无法从类型上穷举——自研 harness 仍应使用一等枚举。回调抛异常时，包装层回一个 control error，CLI 怎么折算看不到（待核验）。
4. **"不可用→放行"的 bug 真的出现在传输层**（事实）。Python v0.2.127 修复：后台任务仍在运行时 stdin 被过早关闭，后台任务的 PreToolUse hooks 被**静默绕过**。CLI v2.1.208 修复：PreToolUse 回调挂起时中断查询，工具仍可能执行。v2.1.210 之前 hook 超时被报成"用户拒绝"，让无人值守会话停下等人。判断：闭合审批集必须在**控制通道**这一层强制——宿主不可达本身就是一种 unavailable；否则类型上的四元组再干净，管道一断照样漏成放行。

### Hooks：事件面、能改什么，以及"沉默"的含义

| 事件（Python 可用） | 能改变什么 | 回调超时的结果 |
| --- | --- | --- |
| `PreToolUse` | `permissionDecision`（allow/deny/ask/defer）、理由、`updatedInput`、`additionalContext` | 阻断该调用 |
| `PostToolUse` / `PostToolUseFailure` | `additionalContext`；PostToolUse 另有 `updatedToolOutput`（任意工具），TS 另有 `classifierContext` | 保留工具结果，继续 |
| `UserPromptSubmit` | `additionalContext`、`suppressOriginalPrompt`，或以顶层 `decision: "block"` 阻断 | 阻断该 prompt |
| `Stop` / `SubagentStop` | 以顶层 `decision: "block"` + `reason` 令其继续工作；`additionalContext` | 视为无决定（照常停下） |
| `PreCompact` | 只能做副作用（收到 `trigger`、`custom_instructions`） | 记录后继续 |
| `PermissionRequest` | 代用户作答 | 无法提示时无决定即拒绝；与宿主回调并存时先到先得 |
| `Notification` / `SubagentStart` | `additionalContext` | 记录后继续 |

Python 的 `HookEvent` 只有上表 10 个；TS 另有二十多个（`SessionStart`/`SessionEnd`、`PostCompact`、`PreModelSwitch`/`PostModelSwitch`、`PermissionDenied`、`TaskCreated`/`TaskCompleted`、`InstructionsLoaded` 等，见快照 §4）。async 输出不能阻断、修改或注入，只适合日志。

判断：这张表把"每个扩展点沉默时意味着什么"写成了显式合同，并且**按该点的安全方向取值**——放行方向的门（PreToolUse、UserPromptSubmit、PreModelSwitch）超时即关，收尾方向的门（Stop）超时即放，因为"停下"本身是安全方向。lab 目前只对审批渠道规定了"unavailable ≠ allowed"，没有推广到所有扩展点。另一个值得审查的点：`PermissionRequest` hook 与宿主回调"谁先决定谁生效"，是两个主体之间的竞速，只有两者同等可信时才可接受。

顺带一个跨来源印证：Claude Code 的 `/goal` 被文档定义为会话级、基于 prompt 的 Stop hook——每个 turn 结束后由小模型判定"未满足 / 已满足 / 不可能"三者之一，判定器不调用工具、只能依据对话里已出现的内容，无进展数轮即停。这与 `analysis/10-learn-claude-code.md` 记录的 s17 goal loop 几乎同形，说明"完成判定交给执行方之外"已经是厂商功能，不只是教学构想。goal 页写明可在 `-p` 下运行；SDK 里把 `/goal` 作为 prompt 发送是否等效，未单独核验（待核验）。

### 上下文：compaction 生存表与"约束不能穿过有损摘要"

文档给出了一张逐类来源的 compaction 去向表（快照 §5）：system prompt 与 output style 仍生效；项目根 CLAUDE.md、无路径限定的 rules、auto memory、plan 模式写下的计划**从磁盘重新注入**；skill 描述重建；读过的文件重读最近修改的至多 5 个；已调用的 skill 正文重新注入，但每个限 5,000 tokens、合计 25,000，截断保留开头；而带 `paths:` 的 rules、子目录 CLAUDE.md、**hooks 早先加入的上下文**都随对话被摘要掉。auto 模式页的一句话把后果说透了：会话里陈述的边界（如"don't push"）不存成规则，每次检查都从 transcript 重读，compaction 删掉那条消息边界就没了，要硬保证就写 deny 规则。agent-loop 页的建议同理：持久规则放 CLAUDE.md，不放初始 prompt，因为 CLAUDE.md 每次请求都重新注入。

判断：`skills/design-agent-tools/SKILL.md` 已有"约束、审批、待办用户指令不得穿过有损摘要"，Agent SDK 给出了这条规则的**操作形态**——一张"来源 × 生存类别"的表，作为 harness 设计文档的必备附件。由此还推出三条更锋利的推论：用户在对话中口头陈述的约束只是可丢的建议，除非 harness 把它提升为规则；经 hook 注入的上下文和对话一样会被摘要，hook 不是持久通道；会被截断重注入的内容要把最关键的指令放在开头。另有一个权衡值得记下：`exclude_dynamic_sections` 为跨用户缓存把动态段移进首条用户消息，文档承认那里的指令权重"略低"——缓存优化与约束强度在同一处此消彼长。

**system prompt 快照**：会话首个请求时记录 system prompt，复用到下一次 compaction，resume 后也不变；中途改指令要作为事实追加进对话（下一条用户消息或 hook 的 `additionalContext`）。文档给的理由同时包括 prompt cache 和 preserved thinking——在强制后者的 API 上改 prompt 会丢掉早先的 thinking。判断：这印证了 `skills/design-agent-tools/SKILL.md`"上下文组装只追加"正在从成本项变成正确性契约。另一个托管陷阱：SDK 不设 `system_prompt` 时用的是**最小 prompt**，缺 `claude_code` preset 的安全与 security 指令，与 `claude -p` 的默认不同；文档的判据是 preset 假设"有人在环、工具完整"，权限模型不同就该自写 prompt——system prompt 与权限模型是耦合的。

tool search 默认把 MCP 工具与非核心内置工具的定义延迟加载，每次最多载入 5 个；已发现的定义在 compaction 吞掉发现它们的消息后失效，需要重搜。并行只给只读工具：自定义工具默认串行，设 `readOnlyHint` 才可与其他只读调用并行；MCP 注解 `readOnlyHint` / `idempotentHint` 还决定 HTTP 服务器连接中断后能否在新连接上重发一次。服务器自描述只被用于调度与重试，用于授权时只能**收紧**（`requiresUserInteraction`；TS v0.3.301 的按工具 `permission_policy` 只有 `always_ask` 与 `always_deny` 两个值）——与 lab 的"工具自述不是授权依据"一致。

### 会话：恢复时重建权限，而不是读取权限

事实（快照 §7）：

- resume 恢复对话、模型、`--agent` 身份、仍活跃 goal 的条件（turn 计数、计时、花费基线重置）；中断的工具调用**不重跑**，模型被告知先检查它是否已生效；后台工作只以"未完成"注记出现，不据此自动开 turn；`--mcp-config`、`--settings`、`--add-dir` 等启动参数不恢复，SDK 每次调用都要重新传选项。
- 权限模式：`-p` / SDK 的 resume 以"新运行会用的模式"起步，不恢复存储的模式；唯一例外是结束于 plan 的会话在条件满足时恢复 plan。终端 resume 恢复存储模式，但 `bypassPermissions` 永不恢复，auto 只在仍满足资格时恢复。"本会话允许"的授权只在同一进程内继承，`--fork-session` 起的新进程要重新批准。
- `defer` 往返：PreToolUse 返回 `defer` → turn 以 `tool_deferred` 结束，宿主收集答案后 resume，**同一工具调用再次触发 PreToolUse**，hook 返回 allow 才执行；resume 时附带新 prompt 则丢弃这个延迟调用；一个 turn 多个工具调用时 `defer` 被忽略。
- 持久授权只有一种形态：`PermissionResultAllow.updated_permissions` 写入 `userSettings` / `projectSettings` / `localSettings`（或只在进程内的 `session`），以及"不再询问"存进 `.claude/settings.local.json` 的规则。
- 从 store 恢复时，包装层把 transcript 物化进临时 `CLAUDE_CONFIG_DIR`，复制凭证时**删去 OAuth `refreshToken`**（防止子进程消耗一次性刷新令牌而吊销父进程凭证），非 UUID 的 resume 值拒绝物化（防路径穿越），临时目录在取消时也清理（`raw/repos/claude-agent-sdk-python/src/claude_agent_sdk/_internal/session_resume.py`）。

对照 lab 的"授权不从序列化状态继承"：大体吻合——审批在恢复时被重新决定，bypass 永不恢复，会话授权不跨进程。Agent SDK 带来三点细化（判断）：

1. **非对称恢复**：从 transcript 恢复一个*更严格*的状态（plan）是安全且可取的，恢复*提权*状态则不行。规则可以写成"恢复限制，重取提权"。
2. **持久授权只能是运营者可审阅的配置**：SDK 唯一能跨会话存活的批准是 settings 文件里的规则，可见、可 diff、按目的地分作用域，从不藏在对话状态里。
3. **新输入使挂起的批准失效**：延迟调用在用户发来新 prompt 时被丢弃，与 lab 已有的"授权对象变了，审批就作废"同构。

goal 条件跨 resume 保留，这一点表面上与 DeepSeek"`GoalActivation` 故意不持久化"相反；但 SDK 的 resume 本身要求宿主随调用提交输入才会开 turn，"重新武装"实际上落在宿主动作上（推论；交互式会话里 goal 的 idle check-in 能否在 resume 后自行开 turn，文档未写，待核验）。

### SessionStore：契约测的是存储语义，风险在投递语义

接口只有两个必需方法 `append` / `load`，四个可选方法（快照 §7.4）。行为要点：子进程先写本地、SDK 再镜像（store 是镜像不是替代）；镜像尽力而为——最多共 3 次尝试，**超时不重试**（原调用可能仍会落地），仍失败就丢弃这批、发 `mirror_error`、查询继续；重试可能重复投递，应按 `entry.uuid` 去重，但有些条目类型没有 uuid（`raw/repos/claude-agent-sdk-python/src/claude_agent_sdk/_internal/transcript_mirror_batcher.py`）；fork 不是字节拷贝，要改写 sessionId 并重映射 UUID；与 file checkpointing 互斥。

Python 随包提供一致性套件 `raw/repos/claude-agent-sdk-python/src/claude_agent_sdk/testing/session_store_conformance.py`，共 14 条契约：顺序、未知 key、空追加、subpath 独立、`project_key` 隔离、列举、级联删除、子键列举、摘要 fold。判断：它锁住的是**存储语义**；文档和注释里真正点名的风险——重复投递、同会话并发 append（read-fold-write 竞争）、本地写入与镜像之间崩溃——都是**投递语义**，一条也不在契约里。还有一个反直觉的耐久性倒置：从 store 恢复的运行结束时会删掉本地副本，store 成为唯一副本，此时一批镜像失败就**无处可补**；看起来更"云原生"的路径在镜像故障下反而比纯本地路径更不耐久。

文档与代码的一处漂移：session-storage 页仍写"Python 恢复时只复制凭证与 `.claude.json`"，但 Python v0.2.137 起代码也复制用户 `settings.json`（去掉插件声明），并有 e2e 测试 `raw/repos/claude-agent-sdk-python/e2e-tests/test_session_store_resume_settings.py` 锁定——以 pin 住的代码为准。

### 预算：上限覆盖子 agent 树，但按估算值执行，且没有墙钟

- `max_turns` 只计 tool-use turns；流式输入下每条排队消息开新 turn 时计数重来，预算则跨消息累积。
- `max_budget_usd` 覆盖子 agent：到线后拒绝再生成子 agent（`Budget limit reached`）、停掉在跑的后台子 agent、以 `error_max_budget_usd` 结束。花费在每个响应**到达后**才比较，所以最多超出一个响应加上在途子 agent 的花费——文档明说要留余量。花费本身是客户端按打包价格表算的**估算**，文档明说不要据此计费或做财务决策。
- 深度默认 3 层、并发默认 20，两个环境变量只接受正整数，**能调不能关**；深度默认值在几天内经历了 5 → 1 → 3（TS v0.3.217 记 5→1，CLI v2.1.219 起为 3）。
- `task_budget` 是另一种机制：把剩余 token 预算**告诉模型**，让它自己收尾——"模型可见的预算信号"与"harness 强制的停止"是两回事，前者不能替代后者。
- hosting 页"已知限制"写明：会话没有顶层超时，子 agent 也没有总运行时间截止，只有"停止产出"看门狗。

判断：对估算值执行的上限必须声明超额语义（SDK 做到了）；可调不可关的上限是好默认，配置错误删不掉它；墙钟这一维两家都留给了宿主——DeepSeek 的 Ralph 也只用轮数约束（`analysis/18-deepseek-harness.md`），所以墙钟只能由宿主负责。resume 后会话花费会恢复（v2.1.277 起），但 `max_budget_usd` 是否把恢复的花费计入上限，文档没说（待核验）。

### 文件检查点：回滚的覆盖面必须写明

精确表述（快照 §10）：开启后，SDK 在经 `Write` / `Edit` / `NotebookEdit` 修改文件**之前**备份；rewind 删除 Claude 创建的文件、把改过的文件恢复到检查点内容。它**不撤销 Bash 命令的改动**，除非那个文件此前已在主对话里被 Write/Edit 改过（于是被跟踪）；子 agent 的编辑不跟踪（前台运行的 `context: fork` skill 例外）；目录的创建、移动、删除不撤销；网络文件不跟踪；检查点绑定会话；回滚文件不回滚对话。v2.1.216 起跳过符号链接与硬链接，之前的版本会**穿过链接写入和删除**。

判断：正确的心智模型是"回滚工具经手的写"，不是"回滚这个会话"；全量回退仍要靠 git 或 worktree 快照。v2.1.216 之前的穿链行为是 lab"按链接删除、不跟随链接"一条的现实反例；整页限制表本身就是 lab"净化机制要写明不覆盖什么"的好样板。

### 子 agent：隔离、fork 默认与"子 agent 输出是不可信数据"

- 非 fork 子 agent 从零开始，父到子唯一的传递物是 Agent 工具的 prompt 字符串；能拿到项目 CLAUDE.md（TS 可 `omitClaudeMd`）和继承或裁剪后的工具，拿不到父的历史、工具结果和 system prompt。CLI v2.1.302 / TS v0.3.302 起，SDK 会话默认允许 `subagent_type: "fork"`（复制当前对话），可用 `Agent(fork)` deny 关闭。子 agent 默认后台运行。
- **模式继承单调**：父为 plan / acceptEdits / auto / bypass 时子 agent 继承父模式；父为 default / dontAsk 时用子定义里的模式，但子定义里的 `bypassPermissions` **永不应用**，auto 仅在可用时应用；auto 模式下子 agent frontmatter 里的 `permissionMode` 被忽略，分类器在生成时、逐动作、返回时三处检查（返回被标记时仍交付但加警告，与 23 号分析的"下行拒、上行警告"一致）。判断：子 agent 只能继承限制，不能靠自己的定义给自己提权——这是委派层面的单调性。
- **输出扫描**（v2.1.210+）：父读取前，中和只有 harness 才会发出的控制标签（如 `<system-reminder>`）与 `Human:`/`Assistant:` 行首的 turn 标记，提到权限配置的内容保留原文但前置 `[harness: …]` 标记，其余一字不改。判断：这是跨边界文本的**结构性转义**规则——夺走 harness 自有标记的权威，而不是删除内容；可直接迁移到任何多 agent harness。
- 令子 agent 提前结束的 API 错误永不作为其结果交付——失败不能伪装成产出。

### CHANGELOG 证据：厂商按模型 ID 退役补偿弱模型的部件

| 日期（npm） | 版本 | 条目 |
| --- | --- | --- |
| 2026-05-14 | TS 0.3.142 | headless 与 SDK 改用 Task 工具，消费方按任务 ID 累积，不再替换整张 todo 快照（语义变化） |
| **2026-08-14** | **TS 0.3.233** | `TaskCreate`/`TaskGet`/`TaskUpdate`/`TaskList`、`TodoWrite` 在 Opus 4.8、Sonnet 5、Fable 5、Mythos 5 及更新模型上 "no longer in the default tool surface"；要保留须在 `tools` 中点名、在 `allowedTools` 中引用，或设 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` |
| **2026-09-10** | **TS 0.3.268** | 反转为白名单：任务工具只在 Claude 3.x、Opus 4.0–4.7、Sonnet 4.0–4.6、Haiku 4.5 上默认提供；todo-tracking 页补充，**包括不认识的模型 ID 在内**一律默认不提供 |
| 2026-10-14 | TS 0.3.300 | 关闭 thinking 的配置在不能关 thinking 的模型上改按 adaptive 运行 |

同类的模型门控还记在文档与 Python CHANGELOG 里：`claude_code` preset 在 Opus 5 上加一行"除非被要求否则不要调用 Agent 工具"，文档同时强调指令只是引导、限额才是强制；auto 模式按模型可用，不支持时退回 Manual；tool search 在早于 Opus 4 / Sonnet 4 的模型上强制预载；Python v0.1.74 的 `xhigh` effort 被称为 Opus 4.7 专属、他处回落为 `high`；Python v0.2.159 与 v0.2.163 因 CLI 默认模型变化导致 CI 失败而在测试中固定模型；Python 仓库 `raw/repos/claude-agent-sdk-python/CLAUDE.md` 要求 CI 用 `claude-opus-4-6` 或更新模型，否则 Claude Code 退回默认权限模式。

判断：

1. 这是"harness 组件是有保质期的假设"最直接的一手证据：厂商在一个版本里按模型代际删掉了一个部件，而这个部件（plan-then-execute 的 todo 工具）正是 `analysis/10-learn-claude-code.md` s05 讲解、`skills/design-ai-agent/SKILL.md` 列为 perishable 的那一类。
2. 关键动作是 **v0.3.268 的反转**：从"对这些新模型移除"（黑名单，未知的未来模型仍拿着拐杖）改成"只对这些老模型保留"（白名单，未知模型默认没有）。按模型门控时，**回落方向取决于部件的种类**：能力补偿押注模型进步，对认不出的模型默认关；放宽权限的功能不押注，认不出就退回更严格的模式（auto → Manual，且切到不支持的模型后不会自动恢复）。
3. 被退役的部件换了理由继续存在：文档把开启任务工具重新定位为"宿主要读这些调用来渲染进度或记日志时才开"。所以假设登记要**按理由**记，不按部件记——同一部件可以对模型过期、对宿主可观测性仍有效。
4. 默认值本身在漂移：深度上限几天内 5 → 1 → 3，`setting_sources` 的默认在 v0.1.0 改为"不加载"后又撤回，CLI 的默认模型变化打断了 CI。不要依赖厂商默认值，在宿主配置里显式写死，并随每次 harness 版本升级重核。

### 包装层的安全教训（开源部分，可直接核验）

Python 包装层自己的 CHANGELOG 是一份"包装子进程时 argv 就是授权通道"的事故清单（快照 §12.2）：v0.2.129 前，`skills=[...]` 里的名字未经校验就拼进以逗号和空格分隔的 `--allowedTools`，构造的名字可以**注入额外权限规则**；v0.2.121 / v0.2.124 把 `--resume`、`--session-id` 与以 `-` 开头的 `extra_args` 值改成 `--flag=value` 单 token，拒绝 Windows 上的 `.bat`/`.cmd` CLI 与含 cmd.exe 元字符的会话 ID；v0.1.60 前，`setting_sources=[]` 被当作假值丢弃，**请求隔离反而加载了全部设置**。v0.2.158 加的 `verbatim_prompts` 默认关闭——不开时用户消息里的 `@path` 会被展开成文件内容、`/command` 会被分发，拼进 prompt 的不可信文本因此能触发文件读取与命令执行。v0.2.137 给 `UserMessage` / `ResultMessage` 加了 `origin`，区分应用提交的 `"human"` prompt 与后台通知、定时触发、同伴消息等自注入 turn。

判断：委派名单要按分隔语法校验，值要与 flag 绑定，"空列表"绝不能回落成"默认"（隔离请求失败时默认放开，是这一类里最坏的失败），prompt 通道本身是解释器，不可信文本进 prompt 时需要逐字模式。turn 来源标注则是"子 agent / 后台消息是数据，不是授权"的前提——宿主得先知道一条消息是谁发起的。

## 工程启发

- **把闭源 harness 当依赖时，测试对象是契约**：权限求值序、resume 后的权限状态、hook 超时语义都写成 e2e 测试，并锁定 harness 二进制版本——SDK 版本与 harness 版本是两条轴，都要记录。
- **单调拒绝对所有能说 allow 的主体成立**，包括宿主加载的插件与扩展，且不随凭证类型或有无 managed 配置而变。"allow 可表达但被支配"（deny 来源全部先行、固定优先级合并、allow 只免提示、不可批准地板）是可接受的第二种形态。
- **必检逻辑放在求值序最前层**；写在末位审批回调里的检查会被前置的自动放行静默遮蔽。
- **每个扩展点声明"沉默 = 什么"**，按该点的安全方向取值，并在控制通道断开时同样成立；宿主不可达就是 unavailable。
- **给每类上下文来源标生存类别**（从源重注入 / 随对话摘要 / 重建 / 丢弃）。硬约束只走规则引擎或从源重注入；会话里口头陈述的边界、hook 注入的上下文都可能被摘要掉。
- **恢复时恢复限制、重取提权**；持久授权只以运营者可审阅的配置存在、不进 transcript；新的用户输入使挂起的延迟审批失效；中断的副作用调用不自动重跑，先核验是否已生效。
- **持久化接缝的一致性套件同时测存储语义与投递语义**（重复投递、并发 append、写本地与镜像之间崩溃），并留意"只有远端副本"的路径在镜像失败时更脆。
- **预算按估算执行时声明超额余量**；上限可调不可关；墙钟由宿主负责。
- **按模型门控的部件按种类定回落方向**：能力补偿对认不出的模型默认关，权限放宽对不支持的模型退回严格模式；假设登记按理由记。
- **不可信仓库**：授予能力的项目配置要过信任门，只做限制的配置总是生效；没有信任对话框的非交互入口（`-p`、SDK）不要加载不可信仓库的 project 来源——SDK 在加载 project 源时会照常执行其 hooks、直接连接 `.mcp.json` 服务器，而省略 `setting_sources` 恰好就会加载它。
- **执行 agent 的作业不持有发布凭证**：Python 仓库自己的 CI 让调用 Claude 的 job 跑在出口防火墙后、用 auto 模式，持有 PyPI 发布权与部署密钥的 job 不调用 Claude，由 agent 产出的 changelog 要先过"纯文本、无类凭证字符串"检查才被发布 job 接收（`raw/repos/claude-agent-sdk-python/CLAUDE.md`）。

## 适用场景

- 需要一个现成、生产强度的本地 coding / ops agent 循环，接受闭源二进制与商业条款。
- 作为自研 harness 的**契约参照物**：拿它的求值序、resume 语义、compaction 生存表、hook 超时语义逐条审自己的设计。
- 作为对照 oracle：同一任务分别跑自研 harness 与 SDK，比较权限决策与恢复行为的差异。
- **不适合**：需要改循环本身（闭源）；只能服务 Claude 模型之外的场景；需要可再分发的全开源栈（CLI 受商业条款约束）；需要墙钟级保证的无人值守长任务（无顶层超时，要宿主自建）；多租户却想沿用默认选项（文档明说默认会读宿主级配置与按目录的 memory）。

## 注意

- **看不到的部分**：agent loop、compaction 算法与摘要 prompt、权限评估器、Bash AST 解析与关键路径识别、分类器 prompt、tool search 的排序、`claude_code` preset 全文、CLI 如何解释回调抛出的 control error、`max_budget_usd` 是否计入 resume 后恢复的花费。本文对这些的陈述都只是"文档如此声明"，在 Python 包装层代码与 `e2e-tests/` 触及之处才有间接核验；文档自己也承认关键路径检查"可能漏掉一些命令"，Bash 解析是权限门而不是沙箱。
- **文档与代码漂移**：store 恢复时 Python 也种入 `settings.json`（v0.2.137 起）而文档没改；子 agent 深度默认要按版本读（TS CHANGELOG 记 5→1，当前 env-vars 文档为 3）。以 pin 住的代码与具体 CLI 版本为准。
- **默认值周更**：本快照窗口内 CLI 从 2.1.2xx 走到 2.1.310，大量行为带版本门槛；本文的默认值以 CLI 2.1.310 为准，复用前按目标版本重核。
- **范围**：Managed Agents、云端会话、auto 模式的服务端审查、claude.ai connector 都不在本文范围。auto 模式直连 API 时可能由服务端审查，对自研本地 harness 可迁移的只是失败语义（无判决即拒绝、熔断阈值、检查中途换模式丢弃判决），不是分类器本身。
- **许可**：TS 包与捆绑 CLI 受商业条款约束，Python 包装层为 MIT；可以借鉴包装层代码与设计，不可再分发 CLI。
- **未测量的厂商断言**："新模型不靠书面 todo 列表也能推进多步工作"、tool search 的准确率与 token 数字、Opus 5 更乐于委派——均为文档陈述，本文没有测量。
- **对 sweep 线索的更正**：v0.3.233 的模型清单还包括 Mythos 5；子 agent 默认深度当前为 3 而非 1；按工具的 `permission_policy` 只存在于 TS（Python v0.2.174 没有）；把 docs.claude.com 短链统一换成 code.claude.com 是对的——短链现在落在通用首页。

## 对最终 skill 的影响

本轮（suite 2.3.0）实际落地：

- `skills/secure-ai-agents/SKILL.md`：单调拒绝须对所有能给出 allow 的主体成立（含插件 / 扩展），与凭据类型和部署方式无关，"allow 可表达但始终被 deny 支配"列为第二种合规形态；必检逻辑放在求值序最前，写在末位审批回调里的检查会被前置自动放行静默跳过；每个扩展点声明"沉默"的含义，控制通道断开同样算 unavailable；恢复时还原限制、重取提权，持久授权只能是可审阅的配置而非 transcript 状态，新的用户输入使挂起的延迟审批失效；只做限制的项目配置可在信任决定之前生效，授予能力的配置等信任之后。
- `skills/design-agent-tools/SKILL.md`：`## Compaction Strategy` 增加"按来源知道压缩后什么还在（从磁盘重注入 / 重建 / 摘要 / 丢弃），只在对话里说过的内容视为可丢"。
- `skills/design-ai-agent/SKILL.md`：`## Perishable vs Durable Design` 增加"按模型门控补偿组件，回落方向按组件种类定：弱模型补偿对认不出的模型默认关闭，放宽权限的功能回退到更严格的模式"（以 v0.3.233 → v0.3.268 为例）；`## Loop Design` 增加"花费上限覆盖整个子 agent 树、跨恢复延续并声明可能超出的幅度，墙钟上限由宿主负责"。
- `skills/test-ai-agents/SKILL.md`：持久化适配器的一致性测试须覆盖投递语义（重复投递、并发追加、本地写与镜像之间崩溃）；端到端测试钉住 SDK、捆绑的 harness 二进制与模型版本。
- `skills/review-ai-agents/SKILL.md`：反模式增加"必检逻辑写在会被自动放行跳过的回调里、插件的批准能推翻 deny""会话里口头说的约束被当作硬保证""恢复后还原了提权状态"。
- `skills/build-ai-agents/references/source-map.md`：登记 `claude-agent-sdk-python` commit `0e89b298`（v0.2.174，捆绑 CLI 2.1.310）、关键 Python 路径、TS CHANGELOG commit `019515d3` 与快照 `raw/docs/claude-agent-sdk.md`。
- `analysis/07-overall-agent-analysis.md`：共识矩阵补入"权限求值序与谁都批不了的地板""压缩后的生存类别""按模型 ID 退役补偿组件"。

提议但本轮未采纳：

- "argv 是授权通道"与"不可信文本进 prompt 时用逐字模式"（secure）：针对 CLI 包装场景，适用面较窄，留在本文。
- 深度与并发上限可调不可关、子 agent 定义只能继承限制不能自授提权、跨边界时中和 harness 自有标记（design-ai-agent）：受体积预算限制，留在本文。
