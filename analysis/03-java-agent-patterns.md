# Java Agent Patterns

Java 侧的资料主要来自 Spring AI examples 和 LangChain4j。它们的共同点是：不要照搬 Python/TS 的动态风格，而是利用 Java 的类型、接口、注解、DI、record 和 builder，把 agent 能力做成可测试的应用服务。

## Spring AI Examples

`agentic-patterns/README.md` 覆盖了常见 workflow patterns：

- chain workflow
- parallelization
- routing
- orchestrator-workers
- evaluator-optimizer

这些 pattern 和 Vercel AI SDK 文档中的 structured workflow 很一致，说明它们是跨语言通用模式。

### Chain Workflow

`ChainWorkflow.java` 把多个 prompt 串成固定流程，每一步的输出作为下一步输入。

适用：

- 有固定步骤的内容处理、数据清洗、分析生成。
- 每一步都能独立测试。
- 不需要模型自主决定工具调用。

实现建议：

- 每一步封装成可命名方法。
- 每一步输入输出尽量是 record/DTO，而不是裸字符串。
- 中间结果要可记录，方便回放和定位问题。

### Orchestrator Workers

`OrchestratorWorkers.java` 先让 orchestrator 产出 typed task list，再交给 worker 处理。

适用：

- 用户任务需要拆成多个独立子任务。
- worker 可以并行。
- 最终需要合成结果。

注意：

- 示例中 worker 处理使用 stream `.toList()`，代码层面不一定真正并行。业务项目如果需要并行，应显式使用 executor、CompletableFuture、虚拟线程或框架内并行设施。
- orchestrator 输出必须有 schema/record 约束，否则下游 worker 难以稳定。

### Evaluator Optimizer

`EvaluatorOptimizer.java` 用 generator/evaluator/refiner 循环改进结果。

适用：

- 质量标准可被明确评分或分类。
- 允许多次 LLM 调用换质量。

注意：

- 必须设置最大迭代次数、成本预算或时间预算。
- evaluator 输出要 typed，例如 pass/fail、score、reason、required changes。
- refiner 不应只拿自然语言评价，最好拿结构化修改建议。

### Function Callback

`SpringAiJavaFunctionCallbackApplication.java` 展示了 Java 函数作为 tool 暴露给模型。

工程原则：

- callback name 稳定且语义明确。
- description 写给模型，不是写给人类 API 文档。
- input type 用 record/class，字段名和描述要自然。
- callback 内部执行真实业务操作前仍需权限检查。

### MCP Annotations

`ToolProvider.java` 示例展示了 `@McpTool` 和 `@McpToolParam`。这适合把 Spring 服务的方法发布为 MCP tool。

工程原则：

- 注解让工具暴露很方便，但也容易暴露过多方法；必须有 allowlist。
- 工具方法返回结构化对象，避免模型解析自由文本。
- 远程 MCP tool 要考虑 auth、tenant、审计、限流。

## LangChain4j

LangChain4j 的价值在于 Java-native 设计：接口、注解、POJO、builder、chat memory、tool executor/provider，而不是把 JS/Python SDK 的风格移植过来。

### AgenticServices

`AssistantMain.java` 展示了 `AgenticServices.agentBuilder`、`sequenceBuilder`、`conditionalBuilder`、`AgenticScope`。

核心模式：

- 每个 sub-agent 是一个接口服务，有自己的 model、memory、outputKey。
- sequence builder 串联多个 sub-agent。
- conditional builder 根据 `AgenticScope` 状态选择 sub-agent。
- `beforeCall` 可以初始化或改写 agentic scope。

工程启发：

- Java 项目里 agent 可以被建模为 service interface，而不是控制器里的一段 prompt。
- `AgenticScope` 类似 workflow state，适合放中间结构化结果。
- outputKey 要稳定，避免多个 agent 写同一个状态键。

### ToolProvider

`ToolProvider.java` 的接口说明很重要：provider 在 AI service invocation 时提供工具。默认每次 invocation 开始调用一次；如果 `isDynamic()` 返回 true，则 tool execution loop 的每次 LLM 调用前都会重新计算工具。

工程启发：

- 多租户、权限变化、状态相关工具适合 dynamic provider。
- 普通静态工具不要动态计算，减少复杂度和成本。
- 每轮 LLM 调用前的 active tool set 应可审计。

### DefaultToolExecutor

`DefaultToolExecutor.java` 展示了 Java tool executor 的边界：

- 反射定位方法。
- 解析 JSON arguments。
- 注入 memory id、invocation context、invocation parameters。
- 调用方法后把返回值转成 text 或 content。
- tool 执行异常可以包装为 tool error result，或配置为向外抛出。

工程启发：

- tool arguments 解析和 tool business logic 要分开。
- void 返回不应让模型猜测，可转成明确成功结果。
- 返回对象默认 JSON 化是合理选择。
- tool exception 要分级：模型可修复的错误作为 tool result；系统错误向外抛出并记录。

### LangChain4j Skills

`langchain4j-skills` 实现了 Agent Skills 规范的 tool-based integration：

- 构造时把 skill 内容和资源加载进内存。
- 向模型暴露 `activate_skill` 工具。
- 有资源时暴露 `read_skill_resource` 工具。
- skill scoped tools 只有激活 skill 后才暴露。
- 模型推理时没有任意文件系统访问，降低任意代码执行风险。

工程启发：

- 在 Java 服务中集成 skill 时，可以不让模型直接读文件，而是把 skill/resource 作为受控 tool。
- progressive disclosure 仍然适用：先列 skill 名称和描述，再由模型激活具体 skill。
- skill scoped tools 是一种很好的权限收敛方式。

## Java 项目落地建议

- Spring 项目优先把 agent 作为 service 层能力，不要塞进 controller。
- tool input/output 使用 record/class，加 Bean Validation 或 schema。
- 使用 DI 注入外部系统 client，不要在 tool 中 new client。
- 为危险工具增加应用权限校验和审批状态。
- 对 chain/router/evaluator/orchestrator 写单元测试，用 fake chat model 固定输出。
- 对真实模型调用写少量 integration/eval，不把所有行为都压到端到端测试。

