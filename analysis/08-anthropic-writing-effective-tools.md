# Anthropic Writing Effective Tools for Agents 分析

> 分析版本：1.0 ｜ 最后更新：2026-05-20 ｜ 来源：Anthropic, Writing Effective Tools for Agents（发布 2025-09-11，抓取 2026-05-20）｜ 快照：`raw/docs/anthropic-writing-effective-tools.md`

这篇文章是 `analysis/06-anthropic-building-effective-agents.md` 的自然后续：前一篇回答"何时需要 agent / workflow"，这一篇把焦点压到 agent 成败最常见的工程边界——tool。它把 `context-and-tools.md` 里已有的 ACI 原则展开成可评测、可迭代的工具设计流程。

已有代码项目已经展示了 schema-first tool、审批边界、MCP server/client 与 tool loop 的实现形态；这篇文章补上一个更上层的问题：不要只把现有 API 机械包成 tool，而要把 tool 当成模型要使用的产品界面来设计。

## 核心抽象

- **tool 是确定性系统与非确定性 agent 的契约**：普通 API 面向开发者，agent tool 面向会误解、会探索、会受上下文限制影响的模型。因此 tool 名称、参数、返回值、错误和描述都是模型可用性的组成部分。
- **agent ergonomics**：好 tool 不只是"能调用"，还要让 agent 容易判断何时调用、如何填参、如何利用结果继续下一步。
- **eval-driven tool design**：工具质量不能只靠代码 review；要用真实任务、transcript、tool-call 指标和 held-out 测试来验证。
- **上下文预算是一等约束**：工具返回过多无关数据会把 agent 的推理预算花在筛垃圾上。高质量 tool 应该主动筛选、摘要、分页、截断并提示下一步。

## 重要模式

- **少而高价值的工具**：优先实现能匹配真实工作单元的工具，而不是一比一暴露后端 endpoint。`search_logs` 通常比 `read_logs` 更适合 agent，因为它减少无关上下文。
- **命名空间与边界**：多个 MCP server 或大量工具同时出现时，service/resource 前缀能帮助 agent 区分能力边界，但具体前缀/后缀方案要用 eval 验证。
- **响应格式可控**：同一个工具可支持 `concise` / `detailed` 等格式，让 agent 在节省 token 和拿到下游 ID 之间切换。
- **模型可修复的错误**：校验错误应说明哪个字段错、期望格式是什么、如何缩小请求，而不是返回内部异常或模糊失败。
- **transcript 驱动优化**：重复 tool call、无效参数、高 token 消耗、工具错误和绕远路径，都是 tool interface 需要调整的证据。

## 工程启发

- **工具不是 API 包装层**：如果直接把每个内部 API 暴露成 tool，agent 会承担过多选择、排序、过滤和聚合工作。更好的做法是在 tool handler 内封装确定性子流程，把 agent 的上下文留给判断。
- **先建 eval 再扩 tool surface**：每加工具或改描述都应该能用一组真实任务比较效果，至少记录 accuracy、tool count、token、runtime、tool errors。
- **工具描述是 prompt surface**：tool description/spec 常比系统 prompt 更直接影响 tool-use 行为，应像公共 API 文档一样维护。
- **MCP 增加了 tool overload 风险**：MCP 让大量工具易于接入，也让命名、筛选、allowlist 和 active tools 更重要。

## 适用场景

- 为 agent 或 MCP server 设计新工具。
- 审查已有工具是否过宽、重叠、返回噪声过多、错误不可修复。
- 优化 tool loop 的成本、成功率和可解释性。
- 把后端 API 包装成 agent-facing capability，而不是给模型一堆低层 CRUD。

## 注意

- 文章强调用 agent 辅助优化 tool，但不能把 agent 反馈当成真值；仍需要可验证答案和 held-out 测试。
- "少而高价值"不等于把所有动作做成一个大工具。工具应贴合自然任务边界，过度合并也会隐藏权限、审计和失败恢复边界。
- 命名空间、Markdown/JSON/XML 响应格式等细节没有全局最优，必须结合模型、任务和 eval 选择。

## 对最终 skill 的影响

本文件推动以下实际改动：

- `SKILL.md`：
  - `Build Workflow` 增加在扩充工具前先用真实任务建立 eval 基线的要求。
  - `Dual-Use Rubric` 把 tool quality 从 schema/description 扩展到工具边界、命名、返回上下文、错误可修复性和 token 预算。
- `references/context-and-tools.md`：
  - 新增 agent-facing tool design 指导：选择高价值工具、避免 endpoint sprawl、命名空间、响应格式、token 控制、可修复错误和 transcript/eval 优化。
- `references/source-map.md`：
  - 记录本文链接、快照和分析路径。
- `analysis/07-overall-agent-analysis.md`：
  - 把"tool ergonomics / eval-driven tool design"纳入跨来源共识。
