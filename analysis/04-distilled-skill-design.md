# Distilled Skill Design

> 分析版本：1.0 ｜ 最后更新：2026-05-18 ｜ 类型：skill 设计取舍（综合全部 7 个代码项目，版本见 `analysis/SOURCE_INDEX.md`）

这一节说明最终 `build-ai-agents` skill 的设计取舍。

## Skill 目标

这个 skill 面向“在具体项目里实现或审查优化 AI agent 功能”的场景，而不是泛泛解释 agent 概念。它应该帮助 Codex 做几件事：

- 判断需求是否真的需要 agent loop。
- 选择单次调用、tool loop、durable graph/workflow、subagent、MCP server/client 等架构。
- 按宿主项目语言和框架落地：TypeScript、Java/Spring、LangChain4j、MCP。
- 设计 tool schema、state、memory、approval、observability、testing。
- 审查已有 agent 代码中的安全、成本、可靠性、可维护性问题，并给出可执行整改计划。
- 避免把安全、权限、错误处理、恢复能力只写进 prompt。

## 为什么不是单一框架 skill

用户后续项目可能是 Java、TS 或其他语言。单一框架 skill 会过早绑定实现。当前 skill 采用“架构优先，框架适配”的结构：

1. 先识别 agent 形态。
2. 再读取对应参考文件。
3. 最后按项目已有栈实现。

这符合 Pi 的 progressive disclosure，也符合实际工程里的 YAGNI：简单任务用简单模式，只有需要时才引入 graph/workflow/MCP/subagent。

## 主 SKILL.md 结构

主文件只包含：

- 触发描述。
- build/extend/review 模式选择。
- 快速工作流。
- 架构选择规则。
- 双用途检查 rubric。
- 审查交付物和完成定义。
- 何时读取哪个 reference。

不把所有细节塞进主文件，避免每次触发都消耗太多上下文。

## References 结构

历史说明：下列是 1.x 单体 skill 的 reference 拆分。2.0.0 后主体内容已迁入 sibling skills，`skills/build-ai-agents/references/` 仅保留 `source-map.md`。

- `skills/design-ai-agent/SKILL.md`（原 `agent-architecture.md`）: 跨框架架构原则和决策表。
- `skills/implement-ts-agents/SKILL.md`（原 `typescript-patterns.md`）: Pi、OpenAI Agents JS、LangGraphJS、Vercel AI SDK 的 TS 模式。
- `skills/implement-java-agents/SKILL.md`（原 `java-patterns.md`）: Spring AI、LangChain4j 模式。
- `skills/build-mcp-capabilities/SKILL.md`（原 `mcp-patterns.md`）: MCP server/client 设计。
- `skills/review-ai-agents/SKILL.md`（原 `review-playbook.md` + `anti-patterns.md`）: 审查已有 agent 代码的定位、分级、报告、反模式和整改模板。
- `skills/secure-ai-agents/SKILL.md`（原 `security-and-safety.md`）: agent threat model、prompt/tool injection、权限与多租户。
- `skills/design-agent-tools/SKILL.md`（原 `context-and-tools.md`）: prompt/context、compaction、retrieval、tool 描述质量。
- `skills/test-ai-agents/SKILL.md`（原 `testing-observability.md`）: 测试、eval、trace、approval、replay。
- `skills/build-ai-agents/references/source-map.md`: 原始资料、本地路径、commit 和官方链接。

## 可直接复用的准则

- Agent = model + instructions + tools + loop/graph + state + memory + approvals + events + tests。
- Tool 要 schema-first，description 写给模型，handler 写给系统。
- 高风险动作必须在工具执行边界做权限和审批。
- 长循环必须有停止条件、预算和可观测性。
- durable 需求出现时，优先 graph/workflow，不要只靠进程内数组保存状态。
- MCP 适合暴露可复用能力，不适合替代业务 workflow。
- Java 项目使用 service/interface/record/DI；TS 项目使用 typed tools、runtimeContext/toolsContext、streaming message boundary。
