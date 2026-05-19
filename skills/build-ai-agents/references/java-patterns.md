# Java Agent Patterns

## Service Boundary

In Java projects, model agents as application services:

- controller receives request and auth context
- service owns workflow/agent orchestration
- tool classes own external actions
- repositories/clients are injected
- records/classes define input and output contracts

Avoid embedding large prompts or tool logic directly in controllers.

## Spring AI Patterns

Use fixed workflows when the steps are known:

- chain: fixed sequential transformations
- router: classify, then call the right path
- parallelization: independent calls, then aggregate
- orchestrator-workers: model creates typed tasks, workers process them
- evaluator-optimizer: generate, evaluate, refine until pass or budget ends

Implementation checklist:

- Use records or DTOs for structured outputs.
- Put max iterations on evaluator loops.
- Use explicit executor/CompletableFuture/virtual threads when true parallelism is required.
- Keep prompts close to the service that owns the workflow.
- Unit test workflow branches with fake chat clients.

## Spring AI Tools

For function callbacks:

- give each tool a stable name
- write descriptions for the model
- use typed request records/classes
- validate permissions inside the callback
- return structured objects instead of free text when possible

For MCP annotations:

- expose only allowlisted methods
- describe each parameter precisely
- return structured content
- add auth, tenant checks, rate limits, and audit logs for remote tools

## LangChain4j Patterns

Use `AiServices` or `AgenticServices` to keep Java-native structure.

Useful patterns:

- interface-based agents
- `MessageWindowChatMemory` or project-specific memory provider
- `sequenceBuilder` for fixed multi-agent pipelines
- `conditionalBuilder` for state-based specialist invocation
- `AgenticScope` for intermediate state
- `outputKey` for stable state writes

Tool provider guidance:

- static providers are enough for fixed tools
- dynamic providers should be used only when active tools depend on request state, permissions, or conversation state
- active tool sets should be logged or traceable

Tool executor guidance:

- parse arguments before business logic
- inject memory id or invocation context explicitly
- convert object results to JSON or structured content
- return model-correctable tool errors as tool results
- throw/log system errors through normal application error handling

## Java Test Strategy

- Unit test tool classes without a real model.
- Unit test workflow routing with fake typed model outputs.
- Integration test one or two real model paths per critical agent.
- Test denial paths for sensitive tools.
- Test max-iteration and timeout behavior for evaluator loops.
- Test memory isolation across users/tenants.

