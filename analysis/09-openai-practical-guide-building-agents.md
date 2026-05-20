# OpenAI Practical Guide to Building Agents 分析

> 分析版本：1.0 ｜ 最后更新：2026-05-20 ｜ 来源：OpenAI, A Practical Guide to Building Agents（发布未标注，抓取 2026-05-20）｜ 快照：`raw/docs/openai-practical-guide-building-agents.md`

OpenAI 这份指南和 Anthropic《Building Effective Agents》有明显交集：都强调不要为了 agent 而 agent，先看任务是否真的需要模型接管流程。但 OpenAI 的增量在于更产品化、部署化：如何判断业务流程适不适合 agent、如何从单 agent 逐步演进到多 agent、哪些 guardrails 和 human intervention 是上线前就要设计的。

对本仓库而言，它补齐了 `build-ai-agents` 当前偏工程实现、偏架构形态的另一半：agent 的 use-case qualification、model baseline、tool risk rating 和上线时的人类接管条件。

## 核心抽象

- **agent 是代用户独立完成 workflow 的系统**：不是所有 LLM 应用都是 agent。只有当模型管理 workflow 执行、动态选工具、判断完成/失败并在 guardrails 内行动时，才进入 agent 范畴。
- **三要素模型**：model、tools、instructions 是 agent 的最小结构。已有代码项目分别展示了这些要素的实现，OpenAI 指南把它们组织成产品/工程团队可操作的设计框架。
- **适用性来自传统自动化的摩擦**：复杂判断、难维护规则、非结构化数据依赖，是 agent 更可能产生价值的信号。
- **guardrails 是分层防御**：relevance/safety/PII/moderation/tool safeguards/rules/output validation 共同降低风险，不能指望单一检查。

## 重要模式

- **先做能力基线，再优化模型成本**：先用强模型建立质量上限和 eval 基线，再尝试用更便宜/更快模型替换子任务。
- **单 agent 优先**：一个 agent 加清晰工具通常更容易评估和维护；只有在复杂条件分支或工具重叠导致失败时再拆多 agent。
- **manager pattern**：一个中心 agent 通过工具调用委托 specialist agent，适合需要统一用户体验和最终综合的流程。
- **handoff pattern**：agent 把控制权交给另一个 specialist，适合对话 triage 或无需中心 agent 持续参与的流程。
- **human intervention**：失败次数超阈值或动作高风险/不可逆/敏感时，把控制权交回人。

## 工程启发

- **用例筛选应进入 Build Workflow**：在实现 agent 前先验证任务是否包含复杂判断、难维护规则或非结构化数据，否则 deterministic code / workflow 更合适。
- **instructions 应来自真实流程资料**：SOP、客服脚本、政策文档和边界情况要被转换成 model-facing routine，而不是只写一句泛化角色提示。
- **tool risk rating 可执行化安全策略**：每个工具按读/写、可逆性、权限、财务或用户影响分级，才能决定是否自动执行、需要 guardrail 还是必须审批。
- **多 agent 不是扩展的默认答案**：OpenAI 对 single-agent-first 的强调，与 Anthropic 的最简优先和本仓库 anti-patterns 中的 over-engineering 判断一致。

## 适用场景

- 从 0 到 1 设计业务 agent 时做 use-case qualification。
- 需要在单 agent、manager agent-as-tool、handoff multi-agent 之间选择。
- 要把 guardrails、人类审批、失败阈值和工具风险写进设计契约。
- 审查已有 agent 是否把简单 LLM 应用误称为 agent，或过早拆成多 agent。

## 注意

- 指南偏 OpenAI Agents SDK 语境，但核心概念不依赖 SDK；本仓库应吸收 decision rules，而不是绑定某个 provider。
- "先用最强模型建基线"不等于生产必须用最贵模型；它是为了先确认任务可解，再分阶段降成本。
- guardrails 不能替代认证、授权、租户隔离和工具 handler 内的权限检查；它们是分层防御的一部分。

## 对最终 skill 的影响

本文件推动以下实际改动：

- `SKILL.md`：
  - `Build Workflow` 增加 use-case qualification、model/eval baseline、human intervention 条件。
  - `Dual-Use Rubric` 增加 tool risk rating、guardrail layer 和 human fallback 检查。
- `references/agent-architecture.md`：
  - 补充何时值得构建 agent、单 agent 优先、manager vs handoff 的选择规则。
- `references/security-and-safety.md`：
  - 补充 layered guardrails、工具风险分级、失败阈值和高风险动作升级为人工处理。
- `references/source-map.md`：
  - 记录本文 HTML/PDF 链接、快照和分析路径。
- `analysis/07-overall-agent-analysis.md`：
  - 把 OpenAI 的 use-case qualification 与 production guardrails 纳入共识矩阵。
