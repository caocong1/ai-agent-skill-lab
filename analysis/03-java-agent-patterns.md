# Java Agent Patterns

> 分析版本：1.2 ｜ 最后更新：2026-10-25 ｜ 覆盖来源：Spring AI Examples + Spring AI 框架 release / LangChain4j ｜ 版本见 `analysis/SOURCE_INDEX.md`
>
> 1.1 变更：新增 `## 2026 年中的版本事实`。原有模式描述核对后仍成立，但基线版本已移动——Spring AI 示例仓整体对齐到 **Spring AI 2.0**，LangChain4j 走到 **1.19.0** 并引入两条命中已分析表面的能力。
>
> 1.2 变更：按 pinned commit 复核（示例仓 `e499007e`；LangChain4j tag `1.22.0` = `7948fba8`），新增 `## 2026-10 版本事实（2026-10-25 核验）`。本轮的实质变化几乎全部来自 **Spring AI 框架**（2.1.0-RC1）与 LangChain4j 1.20–1.22，示例仓只多了 2 个 commit。就地更正 1.1 中"MCP 2026-07-28 新形状在 JVM 生态已落地"的过宽表述，补记 compensation 的适用范围；重写 `## Java 项目落地建议`；新增末节 `## 对最终 skill 的影响

本轮（suite 2.3.0）实际落地：

- `skills/implement-java-agents/SKILL.md`：Version Reality Check 重写到 2026-10（Spring AI 2.1 RC 弃用 `ChatMemory` 家族改用事件溯源 session、`defaultTools()`、钉住的 MCP Java SDK 未实现 2026-07-28、LangChain4j 的错误可见性标记与 2.0 计划默认值、Spring AI 默认把运行时异常消息发给模型、异步方法默认值不同、版本号可能误发布）；新增工具确认要点（策略 OR 组合、逃生口列为审查项、暂停回复从服务端读取、批处理拒绝而不关闭确认）；decision model 用于分类步骤。
- `skills/design-agent-tools/SKILL.md`：错误文本是否对模型可见按错误类型决定、默认不可见；压缩边界以工具轮次（call/result 配对）为单位；多写者时压缩写入用版本检查并在被 append 超车时 rebase，summarizer 拒绝时视图不变。
- `skills/secure-ai-agents/SKILL.md`：工具错误文本列为外泄通道；确认策略只能加确认（OR 组合）。
- `skills/review-ai-agents/SKILL.md`：Java 搜索种子增加 `requiresConfirmation`、`ToolCallConfirmationPolicy`、`ToolErrorVisibleToLlm`，注明 Spring AI 2.1 弃用 `ChatMemory` 家族，并列出风险配置（`sendExceptionMessageToLlm`、关闭确认、自定义 `ToolCallingManager`、名字回退解析、LangChain4j 1.19.1）。
- `skills/build-mcp-capabilities/SKILL.md`：JVM 侧现状一句；客户端侧 `isError: true` 在 fail-closed 错误策略下仍保持模型可见。
- `skills/test-ai-agents/SKILL.md`：错误外泄测试（注入带密钥或 SQL 的工具异常，断言它不出现在模型请求、memory 与最终答案里）。
- `skills/build-ai-agents/references/source-map.md`：更新示例仓与 LangChain4j 的 pin。
- `analysis/SOURCE_INDEX.md`：为 Spring AI 框架单独建版本行（本轮的实质变化全部来自框架 release，只跟踪示例仓会让漂移检测看不见它）。

提议但本轮未采纳：

- 系统提示按 turn 记录版本或哈希（design-ai-agent）：由"每个请求从日志构建"一条覆盖。
- router 用带概率的分类模型且阈值随模型版本重调、Spring 的 round 等于本仓库的 step（design-ai-agent）：受体积预算限制，留在本文。
- 暂停 / 恢复的完整对抗测试矩阵（test）：只采纳了"伪造或改动的审批被拒"与错误外泄测试。
