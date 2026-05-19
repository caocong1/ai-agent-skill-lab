# Professional Reading Links

更新时间：2026-05-18。这里保存官方指南和专业资料入口；仓库源码保存在 `raw/repos/`。可复用 skill 的 canonical source map 在 `skills/build-ai-agents/references/source-map.md`。

## Agent Design Guides

- OpenAI, A Practical Guide to Building Agents: https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- OpenAI PDF, A Practical Guide to Building Agents: https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
- Anthropic, Building Effective Agents: https://www.anthropic.com/engineering/building-effective-agents
- Anthropic, Writing Effective Tools for AI Agents: https://www.anthropic.com/engineering/writing-tools-for-agents
- Anthropic resource, Building Effective AI Agents: https://resources.anthropic.com/building-effective-ai-agents

## Framework Documentation

- OpenAI Agents JS docs: https://openai.github.io/openai-agents-js/
- LangGraphJS docs: https://langchain-ai.github.io/langgraphjs/
- Vercel AI SDK docs: https://ai-sdk.dev/docs
- MCP latest specification: https://modelcontextprotocol.io/specification/latest
- MCP docs: https://modelcontextprotocol.io/docs
- Spring AI reference: https://docs.spring.io/spring-ai/reference/
- LangChain4j docs: https://docs.langchain4j.dev/
- Google Agent Development Kit docs: https://google.github.io/adk-docs/
- Google Vertex AI ADK overview: https://cloud.google.com/vertex-ai/generative-ai/docs/agent-development-kit/overview

## Reading Order

1. Read OpenAI and Anthropic guides for the high-level decision framework: when to use agents, workflows, multi-agent systems, and tool safeguards.
2. Read Pi source to understand how a coding agent loop and skill system can be implemented.
3. Read Vercel AI SDK and OpenAI Agents JS for TypeScript application APIs.
4. Read LangGraphJS when durable state, replay, and human-in-the-loop are required.
5. Read MCP specification and SDK docs when external capabilities need a reusable protocol boundary.
6. Read Spring AI and LangChain4j for Java-native implementation patterns.
