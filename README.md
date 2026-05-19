# AI Agent Skill Lab

这个项目用于沉淀 AI agent 开发学习资料、源码分析和可复用的 Codex skill。目标不是只收集链接，而是把典型项目中的设计模式压缩成后续 Java、TypeScript 或其他语言项目能直接参考的工程方法。

本 skill 同时支持两种用途：(1) 在新项目里设计和实现 agent 功能；(2) 审查并优化已有 agent 代码，产出带 `file:line` 证据、按优先级排序、可执行的整改方案。

## 目录

- `raw/repos/`: 拉取的原始开源项目，只作为学习资料和证据来源。
- `raw/docs/`: 预留给后续下载的白皮书、官方文档快照或文章。
- `analysis/`: 分主题的源码分析、模式总结和结论。
- `skills/build-ai-agents/`: 最终可复用的 Codex skill。

## 当前资料集

当前已经拉取并记录了这些项目：

- `pi`: 重点学习 agent loop、tool execution、harness/session、skills、extensions、subagent。
- `openai-agents-js`: 学习标准 TS agent SDK 的 Agent、tool、handoff、guardrail、approval、run state。
- `langgraphjs`: 学习 durable graph、checkpoint、human-in-the-loop、多 agent handoff。
- `modelcontextprotocol-typescript-sdk`: 学习 MCP server/client、tools/resources/prompts、transport、错误语义。
- `vercel-ai`: 学习 TS/Next 应用层 ToolLoopAgent、WorkflowAgent、streaming UI、approval、MCP client。
- `spring-ai-examples`: 学习 Java/Spring agentic patterns、function callback、MCP annotation。
- `langchain4j`: 学习 Java-native AI service、tool executor/provider、agentic service、skills 集成。

## 使用方式

在别的项目里做 AI agent 功能时，优先参考：

1. `skills/build-ai-agents/SKILL.md`: 给 Codex 的触发和执行流程。
2. `skills/build-ai-agents/references/agent-architecture.md`: 选择 agent 架构。
3. `skills/build-ai-agents/references/typescript-patterns.md`: TS/OpenAI/Vercel/LangGraph/Pi 模式。
4. `skills/build-ai-agents/references/java-patterns.md`: Spring AI 和 LangChain4j 模式。
5. `skills/build-ai-agents/references/mcp-patterns.md`: MCP server/client 设计。
6. `skills/build-ai-agents/references/review-playbook.md`: 审查已有 agent 代码的定位、分级和整改模板。
7. `skills/build-ai-agents/references/anti-patterns.md`: 常见 agent 反模式、检测方式和修复方案。
8. `skills/build-ai-agents/references/security-and-safety.md`: agent 安全威胁模型和审查清单。
9. `skills/build-ai-agents/references/context-and-tools.md`: prompt/context 与 tool 描述优化。
10. `skills/build-ai-agents/references/testing-observability.md`: 测试、回放、审批和可观测性。

如果要让 Codex 自动发现该 skill，可以后续把 `skills/build-ai-agents` 复制或软链到 `~/.codex/skills/`。当前按你的要求保留在 `~/work/ai-agent-skill-lab/` 内。
