# Pi 源码分析

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

## 对最终 skill 的影响

最终 `build-ai-agents` skill 采用 Pi 的几个核心原则：

- 先判断 agent 形态，再选 loop/graph/workflow/MCP。
- 明确 model、tools、state、memory、approval、events 的边界。
- 工具必须 schema-first，错误必须能被模型理解和自我修复。
- 长任务必须有 step budget、token budget、cost budget 或 checkpoint。
- skill 本身也采用 progressive disclosure，把细节拆入 references。

