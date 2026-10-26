# Claude Agent SDK 官方文档结构化摘要（本地 harness 契约面）

> **来源（规范 URL）**：Agent SDK 各页均在 `https://code.claude.com/docs/en/agent-sdk/<page>`（抓取其 `.md` 变体）：`overview`、`agent-loop`、`configuration`、`claude-code-features`、`permissions`、`hooks`、`user-input`、`sessions`、`session-storage`、`subagents`、`file-checkpointing`、`cost-tracking`、`tool-search`、`mcp`、`custom-tools`、`modifying-system-prompts`、`todo-tracking`、`hosting`、`secure-deployment`、`migration-guide`、`python`、`typescript`。这些页把细节委托给 Claude Code 通用页 `https://code.claude.com/docs/en/<page>`，本摘要也读了其中相关部分：`permission-modes`、`permissions`、`hooks`（defer 与 PermissionRequest 两节）、`sessions`、`context-window`、`goal`、`sub-agents`、`mcp`、`env-vars`、`plugins/mods/overview`。
> **索引**：`https://code.claude.com/docs/llms.txt`（"Agent SDK" 一节列 32 页）。规范入口：`https://code.claude.com/docs/en/agent-sdk/overview`。
> **旧链接**：本仓库曾记录的 `https://docs.claude.com/agent-sdk` 与 `https://docs.claude.com/claude-code` 现在 301 到 `https://platform.claude.com/docs`，最终落在通用首页 `/docs/en/home`，**不再指向 SDK 文档**；带完整路径的旧链接（如 `https://docs.claude.com/en/docs/agent-sdk/overview`、`https://platform.claude.com/docs/en/agent-sdk/permissions`）经 302/307 正确落到 code.claude.com 对应页（2026-10-25 用 `curl -IL` 核验）。
> **发布**：滚动更新的文档页，未标注发布日期；页内版本门槛（"requires Claude Code v2.1.xxx"）最高到 v2.1.310，与下列代码快照对应。
> **配套一手材料**：`anthropics/claude-agent-sdk-python` commit `0e89b298e771259378a6cd3734e00d323dff5703`（tag v0.2.174，2026-10-24，捆绑 Claude Code CLI 2.1.310，本地 `raw/repos/claude-agent-sdk-python`）；`anthropics/claude-agent-sdk-typescript` 的 `CHANGELOG.md`，commit `019515d3268e6f94946eb2d8e9edc1ea79c5a6aa`（tag v0.3.310 = main，2026-10-23，仓库无源码）；npm `@anthropic-ai/claude-agent-sdk` 各版本发布时间（`npm view … time`）。
> **抓取**：2026-10-25；`curl` 抓 `.md` 变体，`git ls-remote` / `gh api` / `npm view` 只读查询。
> **性质声明**：转述式结构化摘要，不是原文镜像。选项名、事件名、环境变量、版本号按原样保留（它们是事实而非表达）；引语均短于 15 词。
> **范围**：只摘与本地 / 自托管 harness 有关的内容。Managed Agents、云端会话、服务端分类器审查、claude.ai connector 等托管面按本仓库 scope 决定不摘，出现处只标"不在范围"。

## 1. 定位、运行形态与许可

- **定位**：把 Claude Code 的内置工具、agent loop 与上下文管理做成 Python / TypeScript 库。概述页的对比表把它定义为"嵌入你自己运营的进程"——宿主是你，不是 Anthropic。
- **运行形态**：`query()` 启动并监管一个 `claude` CLI 子进程，经 stdio 以 stream-json 通信；一个会话对应一个子进程，子进程拥有 shell、工作目录和本地 JSONL transcript。两种 SDK 都捆绑原生 CLI 二进制；Python 包内的版本记在 `src/claude_agent_sdk/_cli_version.py`（v0.2.174 捆绑 2.1.310）。`cli_path` / `pathToClaudeCodeExecutable` 可指向自装 CLI，此时工具集与默认值随那个 CLI。
- **非 Python/TS 宿主**：直接以 `claude -p --output-format json` 子进程驱动同一循环。
- **许可**：使用受 Anthropic Commercial Terms 约束，组件自带不同 LICENSE 者除外。Python 仓库 `LICENSE` 为 MIT（包装层代码）；TS 仓库 `LICENSE.md` 为保留全部权利 + 商业条款，仓库只有 `CHANGELOG.md`、`README.md`、`examples/`、`scripts/`，无 SDK 源码。
- **品牌与认证**：第三方产品不得以 "Claude Code" 命名或模仿其视觉；未经批准不得提供 claude.ai 登录，应使用 API key。

## 2. Agent loop、消息与结果

- **循环**：收到 prompt（连同 system prompt、工具定义、历史）→ 模型评估 → 请求工具 → SDK 执行并回填结果 → 重复，直到一次回复不含工具调用。含工具调用的一次往返算一个 turn。
- **`max_turns`** 只计 tool-use turns，默认无上限。流式输入下，在 max-turns 处仍排队的消息会开新 turn，turn 计数重新开始；预算则跨消息累积，`/clear` 才重置。
- **消息类型**：`SystemMessage`（subtype `init`、`compact_boundary`、`informational`、`worker_shutting_down`；TS 中除 `init` 外各自是独立类型）、`AssistantMessage`（每个内容块一条，同一响应共享 message id）、`UserMessage`（工具结果或中途输入）、`StreamEvent`（开启 partial 时）、`ResultMessage`（循环结束；其后仍可能有少量尾随系统事件，应把流读尽）。
- **结果 subtype**：`success`、`error_max_turns`、`error_max_budget_usd`、`error_during_execution`、`error_max_structured_output_retries`。只有 `success` 带 `result` 文本；所有 subtype 都带 `total_cost_usd`、`usage`、`num_turns`、`session_id`。进程崩溃时合成的 `error_during_execution` 费用字段可能为零、`stop_reason` 为 null。`usage` 只覆盖主循环，全树用 `model_usage`。单次 `query()` 在 yield 错误结果后**有意**抛异常；流式会话在错误后保持存活（崩溃除外）。结果还带 `terminal_reason`（`completed`、`max_turns`、`aborted_streaming`、`aborted_tools` 等；Python v0.2.126 起，对齐 TS）。
- **并行执行**：只读工具（`Read`、`Glob`、`Grep`、标为只读的 MCP 工具）可并发；改状态的 `Edit`、`Write`、`Bash` 串行。自定义工具默认串行，设 `readOnlyHint` 才可并行。
- **内置工具**：`Read`/`Edit`/`Write`、`Glob`/`Grep`、`Bash`、`WebSearch`/`WebFetch`、`ToolSearch`、`Agent`/`Skill`/`AskUserQuestion`，以及按模型提供的任务工具（见 §12.1）。
- **effort**：`low`/`medium`/`high`/`xhigh`/`max`，可按会话或按子 agent 设；与 extended thinking 相互独立。
- **被拒的工具调用**：拒绝信息作为工具结果回给模型，模型通常换路径或报告无法继续。

## 3. 权限评估

### 3.1 一次工具调用的检查顺序（SDK permissions 页）

0. **评估之前**：裸名 deny 规则（`Bash`、`"*"`、`"mcp__*"`）直接把工具定义从请求里移除，模型看不到也无法尝试；只有带作用域的 deny（如 `Bash(rm *)`）留到第 2 步匹配。`tools` 选项与子 agent 的 `tools` 子集同样在可见性层面裁剪。
1. **Hooks**（PreToolUse）：可直接拒绝或放行到下一步。hook 返回 `allow` **不跳过**下面的 deny 与 ask 规则；也不能批准被识别为关键路径的 `rm`/`rmdir`；在 plan 模式下对非只读调用无效。
2. **Deny 规则**（`disallowed_tools` + settings.json）：命中即阻断，`bypassPermissions` 下也一样。
3. **Ask 规则**（settings.json）：命中则交给 `canUseTool`，`bypassPermissions` 下也一样。需要用户交互的工具（`AskUserQuestion`、服务器设了 `_meta["anthropic/requiresUserInteraction"]` 的 MCP 工具）即使命中 allow 规则也总是走到回调；`dontAsk` 下这些改为拒绝（该模式从不提示）。组织设为 ask 的 connector 工具同理（不在范围）。
4. **权限模式**：`bypassPermissions` 批准走到此处的一切，关键路径删除除外；`acceptEdits` 批准范围内的文件操作；`plan` 把文件编辑与写文件的 shell 命令送去回调、无视 allow 规则；其他模式落到下一步。
5. **Allow 规则**（`allowed_tools` + settings.json）：命中即批准。工具"自身无需批准"的调用（工作目录内的读、只读 Bash 命令）也在此步解决。关键路径删除与网络路径读取不能被 allow 规则批准。
6. **`canUseTool` 回调**：前面都没解决时才调用。`default` 模式没有回调即拒绝；`dontAsk` 跳过此步直接拒绝；TS 设 `permissionPrompts: 'none'` 时由 `PermissionRequest` hook 决定，否则拒绝。

配套警告：

- **被提前自动批准的调用永远到不了 `canUseTool`**，放在回调里的检查会被静默绕过。TS 在回调与 `bypassPermissions` 或裸名 `allowedTools` 同用时发一次 `CLAUDE_SDK_CAN_USE_TOOL_SHADOWED` 进程警告；Python 发 `CanUseToolShadowedWarning`（只告警不报错，且看不到 settings 文件里的 allow 规则）。必须每次都跑的检查应放 PreToolUse hook——hook 先于其他所有步骤，hook 的 deny 在 bypass 下也成立。
- **`allowed_tools` 是自动批准表，不是可用表**：未列出的工具仍可用，需要批准时落到模式与回调；它也**不约束** `bypassPermissions`（`allowed_tools=["Read"]` + bypass 仍会批准 `Bash`）。要在 bypass 下禁用某工具只能用 `disallowed_tools`。锁死型 agent 的推荐组合是 `allowedTools` + `permissionMode: "dontAsk"`。
- **规则语法要点**：allow 规则的工具名通配只能出现在字面 `mcp__<server>__` 前缀之后（`allowed_tools=["*"]`、`["mcp__*"]` 被忽略）；deny 规则可用 `"*"`、`"mcp__*"`；`Edit(path)` 覆盖所有写文件的内置工具，`Write(path)` 规则永不匹配；`//path` 是文件系统绝对路径，`/path` 锚定在规则来源（经选项传入时即会话 cwd）。

### 3.2 任何模式都不自动批准的"地板"（CLI permission-modes 页）

显式 ask 规则；需要用户交互的工具；被识别的 `rm`/`rmdir` 关键路径删除（根、顶层目录、home、工作目录及其父目录、空变量展开成根的形式等），allow 规则与 hook `allow` 都批不了；跨会话消息保护；开启 `permissions.blockReadsOutsideWorkingDirectories` 时对工作目录外的读。文档明说关键路径检查**可能漏掉一些命令**，不能替代 OS 级沙箱。

**Protected paths**（`.git`、`.claude`、`.vscode`、`.husky`、`.devcontainer` 等目录；shell rc、包管理器配置、`.pre-commit-config.yaml`、`.mcp.json`、`.claude.json` 等文件）：除 `bypassPermissions` 外从不自动批准；auto 下送分类器，`dontAsk` 下拒绝；settings 里的 allow 规则也不能预批准（该检查先于 allow 规则）。

### 3.3 权限模式

| 模式 | 行为摘要 |
| --- | --- |
| `default`（CLI 称 Manual） | 无基于模式的自动批准；需要批准且无 allow 规则的调用交回调，无回调即拒绝 |
| `acceptEdits` | 自动批准工作目录 / `additionalDirectories` 内的编辑与常见文件系统命令；越界、protected path、关键路径删除不批 |
| `plan` | 只探索与计划；编辑永不自动批准（allow 规则或 hook allow 都不行），v2.1.212 起写文件的 shell 命令同样走回调 |
| `dontAsk` | 从不提示：预批准的与本就无需批准的调用运行，其余一律拒绝 |
| `auto` | 模型分类器逐个审查 shell 命令、网络请求等；可用性按模型与提供方门控 |
| `bypassPermissions` | 除"地板"外全部放行；hooks、deny、ask 仍先于模式生效；TS 需 `allowDangerouslySkipPermissions: true`；root/sudo 下拒绝启动（受认可沙箱内除外） |

- **起始模式**：Claude Code v2.1.302 起，`claude -p` 与 Agent SDK 在未设模式时以 `default` 起步（此前不拉取 feature flag 的运行可能以 auto 起步）；交互式终端的内置默认是 `auto`（v2.1.283+）。入口不同，默认不同。
- **仓库不能给自己提权**：项目级 `.claude/settings.json` 或 `settings.local.json` 中的 `defaultMode: "auto"` 或 `"bypassPermissions"` 不生效，只有用户级、managed 或 `--settings` 可以。
- **运行中切换**：`set_permission_mode()` / `setPermissionMode()` 对后续请求立即生效。
- **auto 的模型门控**：Anthropic API 上需 Opus 4.6+、Sonnet 4.6+、Haiku 5.5 或 Fable 系列，更旧模型在任何提供方都不支持；会话中用 `set_model()` 切到不支持的模型会降为 `default`，切回模型也**不会**自动恢复 auto（v2.1.299+）；请求 auto 但不可用时以 Manual 起步。
- **子 agent 的模式继承**：父会话为 `plan`、`acceptEdits`、`auto` 或 `bypassPermissions` 时子 agent 继承父模式（`AgentDefinition` 里写 `acceptEdits` 也照样跑 plan）；父为 `default` / `dontAsk` 时子 agent 用自己的 `permissionMode`，但 `bypassPermissions` 值**永不应用**（v2.1.267+），`auto` 仅在可用时应用。

### 3.4 auto 模式的本地决策序（CLI permission-modes 页；服务端审查变体不在范围）

1. 命中 allow / ask / deny 规则即决（例外：protected path 写入、关键路径删除、需要用户交互的工具、带 per-command 域名的 shell 命令、按内容匹配的 ask 规则、symlink 解析到 protected path 的写、网络路径读）。
2. 只读动作与工作目录内的编辑自动批准（protected path 写入与首次越出工作目录的读除外）。
3. 其余交分类器（关键路径删除默认不交）。
4. 分类器阻断时把理由回给 Claude，多数情况下是规则名（如 `[Data Exfiltration]`）而非解释。

- 进入 auto 时丢弃授予任意执行的宽规则（`Bash(*)`/`PowerShell(*)`、通配解释器、包管理器 run、`Agent` 与 `Monitor` 的 allow 规则），离开时恢复；窄规则如 `Bash(npm test)` 保留。执行会丢弃未提交工作的命令（如 `git reset --hard`、`rm -rf`）之前，Claude Code 先自行运行 `git status`，把有无暂存、修改、未跟踪的工作告诉分类器。
- **分类器的输入**：用户消息、除只读查询外的工具调用、CLAUDE.md 内容；**工具结果被剥离**。TS 的 PostToolUse hook 可返回 `classifierContext`（v0.3.236+），作为宿主提供给分类器的受控上下文。
- **会话里陈述的边界**（如"don't push"）作为阻断信号，但不存成规则，每次检查都从 transcript 重读——**compaction 删掉那条消息，边界就丢了**；要硬保证应写 deny 规则。
- **会话里陈述的批准**：必须点名动作及其危险细节（只说"你可以 force-push"不清除阻断）；默认只覆盖一次；部分阻断不能被会话批准清除。
- **回退**：连续 3 次或累计 20 次阻断 → 暂停 auto、恢复提示（阈值不可配置）；`-p` 无 prompt tool 时到阈值则该动作不执行、运行继续；分类器给不出判决（请求被拒或响应无法解析）→ 拒绝；检查进行中切换模式 → 丢弃新模式本不会请求的判决。
- **子 agent**：生成前评估委派描述，运行中逐动作走同一决策序，结束时审查其工作与报告——被标记的报告仍交付但前置安全警告，分类器不可用时附"先核验再采用"的提示。
- **关键路径删除**：auto 下终端提示带两分钟倒计时，超时即拒绝并告诉 Claude 改走什么；三次超时后同一会话直接拒绝；在 `-p`、Agent SDK 等无终端处直接拒绝。

### 3.5 hooks、规则与 mods 的优先级；工作区信任（CLI permissions 页）

- PreToolUse hook 的决定不绕过 deny 与 ask 规则（含 managed deny）。以退出码 2 阻断的 hook 在规则评估之前就停下调用，因而优先于 allow 规则。
- **mods**（插件中的 JS/TS 事件处理器，处理 `tool.check`，在 PreToolUse 之后作答；其 hooks 在 `-p` 与 Agent SDK 中运行）：机器上有 managed settings、或会话凭证是 Team/Enterprise 登录时，mod 的批准不越过 deny、ask、PreToolUse 阻断与回调；**两者都没有时**（例如用 API key 或长期 OAuth token 的会话），mod 可以批准被 deny 规则拒绝或被 PreToolUse hook 阻断的调用，回调也不会被问到。plan 模式下 mod 不能批准非只读调用。mod 不受沙箱约束。
- **设置优先级**：managed 最高，命令行参数也不能覆盖；任何一层的 deny 都不能被其他层的 allow 推翻；`--disallowedTools` 可在 managed 之外追加限制。嵌入宿主可经 SDK 的 `managedSettings` 选项提供额外策略。
- **工作区信任**：项目 `.claude/settings.json` 的 `permissions.allow` 与 `additionalDirectories` 是授予能力的配置，须接受信任对话框后才生效；deny 与 ask 只做限制，不受信任门影响。`-p` 与 SDK 从不显示信任对话框：此时项目 allow 规则不生效（stderr 警告），但项目 settings 中的 hooks、`env`、`apiKeyHelper` 等照常使用，且在加载 project 源时 `.mcp.json` 的服务器**直接连接、不询问**。在非自写仓库里运行前的建议：`setting_sources` 不含 project、`--bare`、`--settings '{"disableAllHooks": true}'`、`disabledMcpjsonServers`。

### 3.6 审批回调与用户输入（SDK user-input 页 + Python 类型）

- `canUseTool(tool_name, input, context)`；context 含 `suggestions`（建议的权限更新）、`tool_use_id`、`agent_id`、`blocked_path`、`decision_reason`、`title`、`display_name`、`description`。返回 `PermissionResultAllow`（可改写 input，可附 `updated_permissions`，目标为 `userSettings` / `projectSettings` / `localSettings` / `session`）或 `PermissionResultDeny`（`message`，可选 `interrupt`）。Python 文档注明回调只在 "ask" 决策时触发。
- 澄清问题（`AskUserQuestion`）也走同一回调；应用不能往该流程里加自己的问题。
- 回调可以无限期挂起，执行一直暂停；预计等待超过进程寿命时，改用 PreToolUse 的 `defer`（§7.3），让进程退出后从持久化会话恢复。
- Python 包装层：`can_use_tool` 与 `permission_prompt_tool_name` 互斥；设了回调就把后者改为 `"stdio"`，CLI 经控制协议发 `can_use_tool` 请求（`src/claude_agent_sdk/types.py`、`src/claude_agent_sdk/_internal/query.py`）。回调抛异常或返回错误类型时，包装层回一个 control error；CLI 如何把它折算成决定，代码不可见。

## 4. Hooks

- **事件面**：Python 的 `HookEvent` 有 10 个：`PreToolUse`、`PostToolUse`、`PostToolUseFailure`、`UserPromptSubmit`、`Stop`、`SubagentStop`、`PreCompact`、`Notification`、`SubagentStart`、`PermissionRequest`。TS 另有 `PostToolBatch`、`UserPromptExpansion`、`MessageDisplay`、`StopFailure`、`PostCompact`、`PreModelSwitch`、`PostModelSwitch`、`PermissionDenied`、`SessionStart`、`SessionEnd`、`Setup`、`TeammateIdle`、`TaskCreated`、`TaskCompleted`、`Elicitation`、`ElicitationResult`、`ConfigChange`、`InstructionsLoaded`、`WorktreeCreate`、`WorktreeRemove`、`CwdChanged`、`FileChanged`、`DirectoryAdded`。Python 中 `SessionStart`/`SessionEnd` 只能用 settings 文件里的 shell hook。
- **两类并存**：filesystem hooks（settings.json，类型 `command`/`http`/`mcp_tool`/`prompt`/`agent`）与编程回调；两类都在子 agent 内触发，输入带 `agent_id`、`agent_type`。所有输入共有 `session_id`、`cwd`、`hook_event_name`。
- **能改什么**：顶层 `systemMessage`（给用户看，不给模型）、`continue`，以及 `decision: "block"` + `reason`；`hookSpecificOutput` 中，PreToolUse 设 `permissionDecision`（`allow`/`deny`/`ask`/`defer`）、`permissionDecisionReason`、`updatedInput`、`additionalContext`；PostToolUse 设 `additionalContext`、`updatedToolOutput`（任意工具；旧的 `updatedMCPToolOutput` 只管 MCP）、TS 的 `classifierContext`；UserPromptSubmit 可设 `additionalContext`、`suppressOriginalPrompt` 或以顶层 block 阻断；Stop/SubagentStop 以顶层 block 阻断停止使其继续，也可附 `additionalContext`；PreCompact 收 `trigger`（`manual`/`auto`）与 `custom_instructions`，用于归档等副作用；PermissionRequest 可代用户作答。返回 `{}` = 放行不改。
- **聚合**：多个 PreToolUse 决定不一致时 deny > defer > ask > allow。
- **分发**：同一事件的所有 matcher **并发**执行（Python v0.2.82 文档澄清），不得依赖顺序（例如让一个限流 hook 去门控后面的 hook）。matcher 只匹配工具名，不匹配路径或参数。
- **async 输出**：立即继续、不等 hook；因此不能阻断、修改或注入，只适合日志与通知。
- **超时**（默认 600 秒；`UserPromptSubmit`、`PreModelSwitch`、`PostModelSwitch` 30 秒；`MessageDisplay` 10 秒；`SessionEnd` 1.5 秒）及其后果：PreToolUse → 阻断该工具调用（v2.1.210 之前报告为用户拒绝，导致无人值守会话停住等输入）；PostToolUse / PostToolUseFailure → 保留结果继续；UserPromptSubmit → 阻断该 prompt（v2.1.208 之前直接以 `error_during_execution` 结束查询）；Stop / SubagentStop → 视为"无决定"（v2.1.273 之前会连带丢弃其他 hook 的决定）；PreModelSwitch → 阻断切换（未回答即未批准）；其他事件 → 记录并继续。PreToolUse 回调挂起期间中断查询会取消该工具调用（v2.1.208 之前工具仍可能执行）。
- 触到 `max_turns` 时会话可能在 hook 运行前就结束；`UserPromptSubmit` hook 若生成子 agent，可能递归触发自身。

## 5. 上下文、compaction 与 system prompt

- **什么占上下文**：system prompt（每请求，固定小开销）；CLAUDE.md（会话开始经 `setting_sources` 载入，每次请求都带，靠 prompt cache 摊薄）；工具定义（Bash/Read/Edit 等核心内置工具每次都带，MCP 工具与其他内置工具默认被 tool search 延迟）；对话历史（逐 turn 增长）；skill 描述（启动时只载简述，调用时才载全文）。
- **自动 compaction**：接近上限时摘要较早历史、保留近期交互与关键决定，流中出现 `compact_boundary` 系统消息。早期 prompt 里的具体指令可能丢失；文档建议**持久规则放 CLAUDE.md 而不是初始 prompt，因为 CLAUDE.md 每次请求都重新注入**。定制方式：在 CLAUDE.md 里写一节"摘要时必须保留什么"（按意图匹配，标题随意）；`PreCompact` hook；发送 `/compact`。
- **compaction 之后各类内容的去向**（CLI context-window 页）：

| 内容 | compaction 后 |
| --- | --- |
| system prompt、output style | 仍生效 |
| 项目根 CLAUDE.md、无路径限定的 rules、auto memory | 从磁盘重新注入 |
| skill 描述 | 按当前 skills 重建后注入（v2.1.304+） |
| plan 模式写下的计划 | 从磁盘重新注入 |
| 带 `paths:` 的 rules、子目录 CLAUDE.md | 随消息历史被摘要掉，需要时按需重载 |
| 读过或改过的文件 | 重读最近修改的至多 5 个；超过 5,000 tokens 的只留路径引用 |
| 已调用的 skill 正文 | 重新注入，每个上限 5,000 tokens、合计 25,000，最旧的先丢；截断保留文件开头 |
| hooks 早先加入的上下文 | 与对话一起被摘要 |
| 匹配 `compact` 来源的 SessionStart hooks | 重新运行并把输出加入压缩后上下文 |
| 后台命令与后台子 agent | 继续运行，并提醒 Claude 哪些仍在跑以免重复启动 |

- **system prompt 起点**：不设时 SDK 用最小 prompt——只支持工具调用，**缺 `claude_code` preset 的安全与 security 指令**，与 `claude -p` 的默认不同；`{"type": "preset", "preset": "claude_code"}` 可加 `append`；也可给完整自定义字符串或文件。文档的判据：界面、身份、权限模型或任务类型越不像 Claude Code，越应自写 prompt——preset 假设有人在环、工具集完整。
- **system prompt 快照**：会话首个请求时记录 system prompt，并一直复用到下次 compaction（resume 后亦然）；resume 时传入不同的 `append` 或自定义 prompt 不生效。`snapshot: False` 改为每请求重建，只用于迭代措辞；生产应保持记录，否则破坏 prompt cache，并且在强制 preserved thinking 的 API 上会丢掉早先 turn 的 thinking。会话中途要改指令，应把新指令作为**事实陈述追加进对话**（下一条用户消息，或 UserPromptSubmit / PostToolUse hook 的 `additionalContext`）。
- **system reminders**：CLAUDE.md、output style、提交署名、hook 的 `additionalContext`、可用 skill 与子 agent 列表、任务列表提醒、文件变更提示都作为对话内提醒注入，而非放在 system prompt。自写 system prompt 时需加一句说明这些提醒来自应用而非用户。可用 `includeGitInstructions`、`attribution`、`CLAUDE_CODE_DISABLE_CLAUDE_MDS`、`CLAUDE_CODE_DISABLE_ATTACHMENTS` 关掉被替代的内置上下文。
- **跨用户缓存**：`exclude_dynamic_sections` 把每用户动态段（auto memory 位置等）移到首条用户消息，使相同配置跨用户、跨机器共享缓存；代价是这些指令以用户消息身份出现，权重略低。
- **设置源**：省略 `setting_sources` 等于 `["user", "project", "local"]`（v0.1.0 曾改为默认不加载，后撤回）；传 `[]` 才隔离（Python v0.1.59 及以前把空列表当成省略）。不受它控制、总会读取的：managed policy、`~/.claude.json`、auto memory（`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` 关闭）、sandbox 凭证的 deny/mask 条目，以及 claude.ai connector（不在范围）。多租户不要依赖默认选项。
- **CLAUDE.md 叠加无硬优先级**：各层全部可见，冲突时结果取决于模型如何理解；需要在更具体的文件里写明谁覆盖谁。

## 6. 工具、MCP 与 tool search

- **自定义工具** = 进程内 SDK MCP server（`@tool` + `create_sdk_mcp_server`），模型可见名为 `mcp__<server>__<tool>`；Python v0.2.140 起支持 `mcp` 2.x，由 mcp 自己的内存 transport 承载。
- **tool search**（默认开启）：工具定义不进上下文，模型拿到摘要后按需搜索，每次最多载入 5 个；已载入的定义一直可用，直到发现它们的那段消息被 compaction，之后需重新搜索。核心内置工具始终预载。`ENABLE_TOOL_SEARCH` 取值 unset/`true`/`auto`/`auto:N`/`false`。按模型门控：早于 Opus 4 / Sonnet 4 的模型（以及 Agent Platform 上早于 4.5 的模型）一律预载全部定义，变量也覆盖不了。上限 10,000 个工具。文档给出的厂商数字：50 个工具约占 10–20K tokens，同时载入超过 30–50 个时选择准确率下降；少于约 10 个工具时预载更快。
- **MCP 工具注解的用途**：`readOnlyHint` 允许与其他只读调用并行，且 HTTP 服务器（或 connector）连接中断时可在新连接上重发一次；`idempotentHint` 同样允许重发一次；`_meta["anthropic/requiresUserInteraction"]: true` 让服务器要求**每次**调用都有人批准——任何模式与 allow 规则都跳不过，不提供"不再询问"，`dontAsk` 下拒绝，`--permission-prompt-tool` 的 allow 被改写为 deny，SDK 的 `canUseTool` 可以批准（宿主被假定会展示给真人）。
- **按工具的权限策略**：TS v0.3.301 起 sdk 型 MCP server 配置的 `tools` 条目可设 `permission_policy` 为 `always_ask` 或 `always_deny`（只有收紧取值；Python v0.2.174 无此字段）；TS v0.2.111 起远程 http/sse 条目可带按工具的 `permission_policy`，并入会话的 allow/deny 规则（取值未在文档中查到）。
- `strict_mcp_config` 只用代码传入的 MCP 服务器；TS v0.3.142 起 MCP 服务器默认后台连接，tool search 开启时首个 turn 只为 `alwaysLoad` 或被点名的服务器等待至多 2 秒。

## 7. 会话与持久化

### 7.1 continue / resume / fork

- 会话持久化的是**对话**，不是文件系统；fork 只分叉历史，fork 出的 agent 改的文件对同目录所有会话都可见。文件回退要用 file checkpointing（§10）。
- continue = 当前目录最近的会话；resume = 指定 session ID；fork = 复制历史到新 ID，原会话不变。本地路径 `~/.claude/projects/<encoded-cwd>/*.jsonl`；v2.1.223 起可跨目录查找 ID，但只限本机。
- 跨主机三条路：SessionStore；搬运 JSONL；或**不依赖 resume**，把需要的结果作为应用状态传进新会话——文档称后者常更稳健。
- TS `persistSession: false` 只在内存里；Python 无对应选项，用 `CLAUDE_CODE_SKIP_PROMPT_HISTORY` 抑制写入。SDK 与 `-p` 会话不出现在 CLI 的会话选择器与 `claude --continue` 中。
- Python v0.2.137 新增 `resume_session_at`（从较早条目截断恢复）与 `resume_drops_turn`（校验被丢弃的只是指定 turn 的条目），用于"回到上一条 prompt 之前"而不静默丢掉未观察到的消息。

### 7.2 resume 恢复什么（CLI sessions 页）

- **恢复**：对话历史（若已 compaction，从最后一次摘要 + 未被摘要的消息继续）；模型；`--agent` 身份及其工具限制；仍活跃的 goal（条件保留，turn 计数、计时、花费基线重置）；未过期的会话级定时任务。
- **中断的工具调用**：不完成、不重跑；Claude 看到它被标为结果前中断，并被告知先检查是否已生效再决定是否重跑（除非设 `CLAUDE_CODE_RESUME_INTERRUPTED_TURN`）。
- **后台工作**：以"未完成"注记出现在 transcript 里，Claude Code 不据此自动开 turn。
- **启动参数不恢复**：`--mcp-config`、`--settings`、`--plugin-dir`、`--fallback-model`、`--add-dir` 须重传；settings 文件在启动时重读。
- **权限模式**：`-p` / SDK 的 resume 以"一个新运行会用的模式"起步，**不恢复存储的模式**；唯一例外是结束于 plan 的会话在条件满足时恢复 plan（传了 permission prompt tool、未传 `--permission-mode`、非 fork、`ExitPlanMode` 未被 deny）。终端 resume 恢复存储的模式，但 `bypassPermissions` 永不恢复，`auto` 只在账户仍满足条件时恢复。
- **"本会话允许"的授权**：同一进程内 `/branch` 继承；`--fork-session` 起的新进程不继承，需重新批准。
- **花费**：v2.1.277 起会话总额在进程正常退出时写入 transcript，resume / fork 时恢复，结果已含此前花费（再相加会重复计数）；之前经 SDK 或 `-p` resume 的会话从零计。

### 7.3 `defer`：把挂起的批准变成可恢复状态（CLI hooks 页）

1. PreToolUse hook 返回 `permissionDecision: "defer"` → 工具不执行，turn 以 `stop_reason: "tool_deferred"` 结束，result 携带 `deferred_tool_use`（工具调用 id、name、执行前捕获的 input），挂起的调用留在 transcript。
2. 宿主在自己的界面收集答案后 resume；**同一工具调用再次触发 PreToolUse**，hook 返回 `allow`（可带 `updatedInput`）才执行。
- 无超时、无重试上限，会话受 `cleanupPeriodDays`（默认 30 天）清理约束。恢复时工具已不可用 → 首个结果为 `tool_deferred_unavailable`（`is_error: true`），hook 不触发。
- resume 时（或之后）若发了新 prompt，Claude Code 不带该工具结果直接回答，**丢弃**这个延迟调用；只有不带 prompt 地 resume 才继续等待，hook 可再次 `defer`。
- 只在一个 turn 恰好一次工具调用时有效；批量调用时 `defer` 被忽略（resume 只能重跑一个工具）。只在 `-p` / SDK 下生效。`updatedInput` 不能与 `defer` 同用。
- 相关：`PermissionRequest` hook 在无法提示的会话（如非交互模式的后台子 agent）中仍运行，没有 hook 给出决定即拒绝；与宿主回调并存时谁先决定谁生效。

### 7.4 SessionStore

- **接口**：必需 `append(key, entries)` 与 `load(key)`；可选 `list_sessions`、`list_session_summaries`、`delete`、`list_subkeys`。`SessionKey` = `project_key`（cwd 的稳定编码，因此须在相同 cwd 下恢复）+ `session_id` + 可选 `subpath`（子 agent transcript 或 sidecar，当作不透明后缀）。
- **语义**：`load` 返回与 `append` 深相等、同序的条目（不要求字节相等）；未知会话返回 None；删除主键须级联删除子键与摘要；摘要 sidecar 用 `fold_session_summary` 在 `append` 内维护，子 agent 批次不计入，同会话并发 `append` 须以事务、CAS 或每会话锁串行化 read-fold-write。
- **双写**：子进程总是先写本地，SDK 再把同一批转发给 `append`——store 是镜像不是替代。新会话的本地 transcript 留存；**从 store 恢复的运行**把 transcript 物化进临时 `CLAUDE_CONFIG_DIR`，运行结束连同本地副本一起删除，此时 store 是唯一的持久副本。
- **镜像尽力而为**：`append` 失败最多共 3 次尝试、短退避；超时**不重试**（原调用可能仍会落地）；仍失败就丢弃这批、在迭代器里发 `{type: "system", subtype: "mirror_error"}`、查询继续。重试可能重复投递，应按 `entry.uuid` 去重（有些条目类型没有 uuid）。Python 有 `session_store_flush`（`batched` / `eager`）。
- **互斥**：与 file checkpointing 同用（备份只写本地、不镜像）或与 TS `persistSession: false` 同用，启动即抛错。
- **其他**：`get_session_messages` 返回恢复时模型会看到的 post-compaction 链（例：503 条原始条目对应 18 条消息），要全量原始历史直接 `load`；`fork` 不是字节拷贝，要改写每个 sessionId 并重映射消息 UUID；SDK 从不删除 store 里的东西，保留期由适配器负责。
- **恢复时种入临时目录的文件**：文档称 TS 复制凭证、`.claude.json` 与用户 `settings.json`（去掉 `enabledPlugins`、`extraKnownMarketplaces` 等），Python 只复制凭证与 `.claude.json`。**这一句对 Python 已过时**：Python v0.2.137 起也复制 `settings.json` 与 `cowork_settings.json`（去掉插件声明），见 `src/claude_agent_sdk/_internal/session_resume.py` 与 e2e 测试 `e2e-tests/test_session_store_resume_settings.py`。复制的凭证会删去 OAuth `refreshToken`，避免子进程消耗一次性刷新令牌而吊销父进程凭证；非 UUID 的 resume 值不物化（防路径穿越）。
- **参考适配器**：S3（每次 append 一个 part 文件，load 时排序拼接）、Redis（每会话一个 list + 有序索引）、Postgres（每条目一行 jsonb）；只供复制，不发布为包。
- **一致性测试**：Python 随包提供 `claude_agent_sdk.testing.run_session_store_conformance(factory)`，工厂每条契约调用一次以隔离；未实现的可选方法自动跳过。TS 需从示例目录复制 `shared/conformance.ts`。Python 套件的 14 条契约见 §12.3。

## 8. 子 agent

- **定义方式**：`agents` 参数（推荐）、`.claude/agents/` 下的 markdown 文件、或内置 `general-purpose`（Agent 工具不带 `subagent_type` 时使用；`CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1` 移除）。同名时代码定义覆盖文件定义。
- **`AgentDefinition` 字段**：`description`、`prompt`、`tools`、`disallowedTools`、`model`、`skills`（预载至多前 32 个）、`memory`、`mcpServers`、`initialPrompt`、`maxTurns`（触顶时输出标为 partial，可 resume）、`background`、`effort`、`permissionMode`；TS 另有 `autoCompactWindow`（100,000–1,000,000 tokens，让子 agent 比主会话更早 compaction，v0.3.296）与 `omitClaudeMd`（v0.3.271），Python 无这两个字段。
- **非 fork 子 agent 的上下文**：全新上下文，父到子唯一的传递物是 Agent 工具的 prompt 字符串；收到自己的 system prompt、项目 CLAUDE.md（除非 `omitClaudeMd`）、继承或裁剪后的工具定义；收不到父会话历史、工具结果和父的 system prompt。有 `SendMessage` 的子 agent 首轮会拿到其他具名 agent 的列表。继承父的 extended thinking 配置。
- **fork**：复制到目前为止的对话而非从零开始。Claude Code v2.1.302 / TS v0.3.302 起 SDK 会话默认允许 Claude 以 `subagent_type: "fork"` 启动 fork；用 `disallowed_tools=["Agent(fork)"]` 或 `CLAUDE_CODE_FORK_SUBAGENT=0` 关闭。
- **前台 / 后台**：默认后台运行，Agent 工具结果为 `status: "async_launched"`，报告在之后的 turn 到达；下一步需要报告时会阻塞等待。
- **输出扫描**（v2.1.210+）：父读取前扫描子 agent 最终消息——中和只有 harness 才会发出的控制标签（如 `<system-reminder>`，在尖括号后插反斜杠，不删内容）；以 `Human:`/`Assistant:` 开头的行在冒号前加反斜杠；提到权限配置（`.claude/settings.json`、`bypassPermissions` 等）的保留原文；控制标签或权限配置命中时前置一行 `[harness: …]` 标记。除此之外不删改文本。
- 令子 agent 提前结束的 API 错误（如限流）永不作为其结果交付。子 agent transcript 独立存储。
- **上限**：深度 `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` 默认 3 层（v2.1.217–2.1.218 默认为 1，v2.1.219 起为 3；TS v0.3.217 的 CHANGELOG 记的是 5→1）；并发 `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` 默认 20，到达时返回 `Concurrent subagent limit reached`；两个变量只接受正整数、其他值被忽略——**能调不能关**。花费见 §9。
- **Opus 5 的委派倾向**：文档称 Opus 5 比早期模型更乐于委派；使用 `claude_code` preset 且模型为 Opus 5 时，Claude Code 在 system prompt 里加一行"除非被要求否则不要调用 Agent 工具"；自写 prompt 时没有这一行。文档强调指令只是引导，限额才是强制。
- 大规模编排（几十到几百个 agent）用 TS 的 `Workflow` 工具（v0.3.149+），编排移到对话外的脚本里。

## 9. 预算与成本

- `max_turns`（tool-use turns）与 `max_budget_usd`（估算花费）默认都不限；触顶分别得到 `error_max_turns`、`error_max_budget_usd`。文档建议生产 agent 默认设预算。
- **花费上限覆盖子 agent**：子 agent 的花费计入总额；到达上限后再生成子 agent 返回 `Budget limit reached`，仍在运行的后台子 agent 被停掉（需 Claude Code v2.1.217+）。
- **超额余量**：花费在每个响应到达后才与上限比较（成本取自响应附带的 usage），所以越线的那个响应会完成并计入，再加上当时仍在运行的子 agent 在停下前的花费——设上限要留余量。
- **花费是估算**：`total_cost_usd` 由客户端按构建时打包的价格表计算（除非设了 `modelPricing`），价格变化、SDK 不认识的模型、无法建模的计费规则都会导致漂移；文档明说不要据此向终端用户计费或触发财务决策。`error_max_budget_usd` 的 `usage` 不含越线的那个响应，`total_cost_usd` 与 `model_usage` 含。每条 AssistantMessage 上的 `output_tokens` 是 `message_start` 时的占位值，真实值在 result 里。
- `task_budget`：API 侧的 token 预算（beta），**让模型知道自己剩多少**，以便自行收尾。
- 每个子 agent 可设 `maxTurns`、`effort`，TS 还可设 `autoCompactWindow`。
- **没有墙钟上限**：hosting 页"已知限制"写明会话没有顶层超时，子 agent 也没有总运行时间截止；`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS` 只是"停止产出"看门狗。

## 10. 文件检查点（file-checkpointing 页）

- 开启 `enable_file_checkpointing` 后，SDK 在经 `Write`、`Edit`、`NotebookEdit` 修改文件**之前**备份；用户消息带检查点 UUID（需 `extra_args={"replay-user-messages": None}`）；`rewind_files(uuid)` 删除 Claude 创建的文件、把修改过的文件恢复到该点内容。
- **只回滚它经手的写**：Bash 命令（如 `sed -i`）对文件的改动**不撤销**，除非该文件此前已在主对话里被 Write/Edit 修改过（被跟踪）；子 agent 的编辑不跟踪（前台运行的 `context: fork` skill 例外），只能在主对话已改过的文件上被连带回退，其余用 git；目录的创建、移动、删除不撤销；远程 / 网络文件不跟踪；检查点绑定在创建它的会话上。
- 回滚的是磁盘文件，不回滚对话。
- v2.1.216 起跳过符号链接、硬链接与非常规文件，以及父目录已不在原处或备份无法安全读取的路径，`RewindFilesResult.skippedLinks` 计数；之前的版本会穿过链接写入和删除。
- 与 SessionStore 互斥（备份只在本地）。

## 11. 自托管与安全部署（只摘本地 / 自托管部分）

- **子进程模型的后果**：每个 agent 都是绑定本地状态的长寿进程；transcript、CLAUDE.md、工作目录产物默认都在容器本地盘，重启、缩容、换节点即丢。SessionStore 只镜像 transcript。
- **会话模式**：短命、长命、混合、单容器多 agent 四种；长命会话按 `sessionId` 一致性哈希固定到容器。容量公式：每主机 agent 数 =（主机内存 − 开销）/ 单会话内存峰值（1 GiB 只是下限）。
- **多租户隔离**：`setting_sources=[]`、`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`、每租户独立 `CLAUDE_CONFIG_DIR` 与 `cwd`、代理处按租户的出站规则。
- **认证**：入站认证放在 agent 前面的网关；出站工具凭证不进 agent 环境，由代理在请求离开容器后注入；模型调用可经 `ANTHROPIC_BASE_URL` 走注入 key 的代理。
- **可观测性**：继承环境中的 OpenTelemetry 配置；prompt 文本与工具输入默认不导出。
- **安全原则**（secure-deployment 页）：把凭证放在 agent 所在边界之外；最小权限（只挂需要的目录、优先只读、经代理限定端点、丢弃 Linux capabilities）；纵深防御。Bash 权限匹配先把命令解析成 AST——解析不干净或不匹配 allow 规则的命令须显式批准，`eval` 等少数结构总要批准；文档自称这是**权限门而不是沙箱**，除关键路径与 protected path 检查外不按目标或效果推断危险。WebSearch 结果经摘要后才进上下文。`sandbox-runtime` 用 bubblewrap / sandbox-exec + 内置代理限制文件与网络，但与宿主共享内核、代理不做 TLS 检查（可被 domain fronting 绕过）。

## 12. CHANGELOG 摘录

### 12.1 按模型代际开关的 harness 部件（TS CHANGELOG @ `019515d3`；日期为 npm 发布时间）

| 版本（日期） | 条目（转述，标识符原样） |
| --- | --- |
| 0.2.136（2026-05-08） | 弃用 `TodoWrite`，预告改用 Task 工具 |
| 0.3.142（2026-05-14） | 破坏性：headless 与 SDK 会话改用 `TaskCreate`/`TaskUpdate`/`TaskGet`/`TaskList`；消费方应按任务 ID 累积，而不是替换整张快照 |
| 0.3.217（2026-07-21） | 子 agent 默认不再嵌套生成（深度上限 5→1）；新增并发上限 20（CLI v2.1.219 又把深度默认改为 3） |
| **0.3.233（2026-08-14）** | 任务工具（`TaskCreate`/`TaskGet`/`TaskUpdate`/`TaskList`、`TodoWrite`）在 Opus 4.8、Sonnet 5、Fable 5、Mythos 5 及更新模型上 "no longer in the default tool surface"；要保留须在 `tools` 中点名、在 `allowedTools` 中引用，或设 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` |
| **0.3.268（2026-09-10）** | 反转为白名单：任务工具只在 Claude 3.x、Opus 4.0–4.7、Sonnet 4.0–4.6、Haiku 4.5 上是默认工具，其余模型须显式列出。todo-tracking 页补充：包括 Claude Code 不认识的模型 ID 在内，一律默认不提供；理由是新模型不靠书面 todo 列表也能推进多步工作（厂商断言）；并把开启任务工具重新定位为"应用要读这些工具调用来渲染进度或记日志时才开" |
| 0.3.300（2026-10-14） | `thinking: {type: 'disabled'}` 与 `maxThinkingTokens: 0` 在不能关闭 thinking 的模型上改为按 adaptive thinking 运行 |
| 0.3.302（2026-10-16） | SDK 会话默认开启 fork 子 agent |

同类、但记在文档或 Python CHANGELOG 里的模型门控：auto 模式按模型可用、切到不支持的模型自动降级且不自动恢复（§3.3）；tool search 在早于 Opus 4 / Sonnet 4 的模型上强制预载（§6）；`claude_code` preset 在 Opus 5 上加一行抑制委派（§8）；Python v0.1.74 的 `xhigh` effort 称是 Opus 4.7 专属、其他模型回落为 `high`；Python v0.1.65 的 `ThinkingConfig.display` 用于覆盖 Opus 4.7 默认不显示 thinking 文本；Python v0.2.159 与 v0.2.163 因 CLI 的默认模型变化导致 CI 失败而在测试中固定模型；Python 仓库 `CLAUDE.md` 要求 CI 中调用 Claude 的 job 使用 `claude-opus-4-6` 或更新的模型，否则 Claude Code 退回默认权限模式。

### 12.2 Python 包装层自身的修复与加固（`CHANGELOG.md` @ `0e89b298`）

- v0.1.60：`setting_sources=[]` 被当作假值丢弃，CLI 改用默认设置——请求隔离反而加载了全部设置。
- v0.2.82：文档澄清同一事件的 hooks 并发分发。
- v0.2.121：`--resume`、`--session-id` 改用 `--flag=value` 单 token 传递，防止以 `-` 开头的值被当作独立 flag；构建脚本校验 `CLAUDE_CLI_VERSION` 并去掉 shell 插值。
- v0.2.124：拒绝在 Windows 上启动 `.bat`/`.cmd` 形式的 CLI（BatBadBut 类命令注入）；Windows 上含 cmd.exe 元字符或换行的 `resume`/`session_id` 直接报错；以 `-` 开头的 `extra_args` 值同样改用 `--flag=value`。
- v0.2.127：后台任务仍在运行时 `query()` 在首个 `result` 帧就关闭 stdin，导致后台任务的 SDK MCP 调用失败，并**静默绕过了 PreToolUse hooks**；改为等所有在途任务结束。v0.2.160 进一步改为监听 `session_state_changed`，直到 CLI 报告 idle（带 10 分钟上限）。
- v0.2.129：`skills=[...]` 里的名字未经校验就拼进以逗号和空格分隔的 `--allowedTools`，构造的名字可以**注入额外权限规则**；改为校验并拒绝。
- v0.2.137：store 恢复时种入用户 `settings.json`（见 §7.4）；`ConversationResetMessage`；`UserMessage`/`ResultMessage` 新增 `origin`，区分应用提交的 `"human"` prompt 与后台任务通知、定时触发、同伴消息等会话自注入的 turn。
- v0.2.140：`ResultError` 携带结构化错误（`subtype`、`terminal_reason`、`api_error_status` 等）；`can_use_tool` 支持字符串 prompt。
- v0.2.158：`verbatim_prompts`（默认 `False`）：为 `True` 时用户消息原样交给 CLI，不做 `@path` 文件展开、不分发 slash 命令，防止拼进 prompt 的不可信文本触发意外的文件读取或命令执行。
- v0.2.164：仓库 CI 加固，调用 Claude 的 workflow 改用出口防火墙 runner、网络白名单与 auto 权限模式，并加检查 workflow。现行细节见仓库 `CLAUDE.md`：白名单保持 `mode: enforce`；持有 PyPI 发布权与部署密钥的 job 不调用 Claude；由 Claude 生成的 changelog 只有是纯文本且不含类凭证字符串时，才被发布 job 接收。

### 12.3 Python 一致性套件的 14 条契约（`src/claude_agent_sdk/testing/session_store_conformance.py`）

必需（append + load）：1 追加后读回同序同值；2 未知 key（含未知 subpath）返回 None；3 多次追加保持调用顺序；4 追加空列表是空操作；5 subpath 与主 transcript 独立存储；6 `project_key` 相互隔离。可选：7 `list_sessions` 列出该项目的会话；8 不含子 agent subpath；9 删除主键后读回 None；10 删除主键级联到子键；11 带 subpath 的删除只删该子键；12 `list_subkeys` 列出 subpath；13 不含主 transcript；14 `list_session_summaries` 返回持久化的 fold 结果。套件**不**检验：重复投递下的 uuid 去重、同会话并发 `append`、本地写入与镜像之间崩溃——这三项在文档和 `transcript_mirror_batcher.py` 的注释里有要求，但不在契约中。

## 13. 本快照看不到的部分

TS SDK 与 CLI 二进制闭源：agent loop 实现、compaction 算法与摘要 prompt、权限评估器、Bash AST 解析器与关键路径识别、分类器 prompt、tool search 的排序、`claude_code` preset 全文、CLI 如何解释回调抛出的 control error、`max_budget_usd` 在 resume 后是否计入已恢复的会话花费——以上只能读到文档的自我描述，或从 Python 包装层的 e2e 测试（`e2e-tests/`）间接观察，代码层面不可核验。
