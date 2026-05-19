# Anthropic Building Effective Agents 分析

> 分析版本：1.0 ｜ 最后更新：2026-05-19 ｜ 来源：Anthropic, Building Effective Agents（发布 2024-12-19，抓取 2026-05-19）｜ 快照：`raw/docs/anthropic-building-effective-agents.md`

这是本仓库分析的第一个非代码来源。前面 7 个项目（Pi、OpenAI Agents JS、LangGraphJS、MCP TS SDK、Vercel AI SDK、Spring AI Examples、LangChain4j）回答的是"怎么实现"，这篇 Anthropic 工程文章回答的是"该不该做、做到什么程度"。它不绑定任何框架，给出的是判定框架，正好补上 skill 里一直隐含但没有被单独来源支撑的那条主线：先用最简单的方案，能测到收益再加复杂度。

文章把 agentic system 明确切成两类：**workflow**（用预定义代码路径编排 LLM 和工具）和 **agent**（LLM 动态决定自己的流程和工具使用）。这个区分是整篇文章的地基，也是本轮 skill 优化最值得吸收的一点——它给"是否需要 agent loop"提供了一个权威的、可引用的判据，而不只是工程经验。

## 核心抽象

- **Augmented LLM 作为基础构件**：LLM + retrieval + tools + memory。现代模型能主动生成检索查询、选工具、决定保留什么。落地重点只有两条：按场景裁剪能力、给一个简单且文档良好的接口（这与本仓库一贯强调的 schema-first tool、progressive disclosure 是同一方向）。
- **workflow vs agent 的二分**：workflow 是工程师把控制流写死、LLM 只填空；agent 是 LLM 自己决定下一步。两者不是优劣关系，而是按"步骤可不可预测"选择。
- **environment feedback 是 agent 的必要条件**：agent 每一步都要从环境拿 ground truth（工具结果、代码执行结果），否则它不是 agent，只是多轮自说自话。这点和 Pi `agent-loop.ts` 把工具结果按序回填、LangGraph 每个 super-step 后 checkpoint 是同一个工程事实的不同表述。

## 重要模式

文章给了五种 workflow 模式 + 一种 agent 形态，正好可以和已分析项目里的实现对齐：

- **Prompt Chaining**：固定顺序拆步，步间可加程序化 gate。对应 Spring AI 的 Chain Workflow、LangGraph 里写死的线性图。
- **Routing**：先分类再分流，每类单独优化；也可用于"简单问题走小模型、难问题走大模型"的成本路由。对应 OpenAI Agents JS 的 handoff、Spring AI Orchestrator 的前置分类。
- **Parallelization**：sectioning（独立子任务并行）与 voting（同一任务多跑取信度）。对应 OpenAI Agents JS 里"很多并行场景直接 `Promise.all(run(...))` 再合成"的结论——并行不是神秘机制。
- **Orchestrator-Workers**：中心 LLM 按输入动态拆子任务再综合，和 parallelization 的差别在于子任务不是预先固定的。对应 Spring AI Orchestrator Workers、Pi subagent 的 chain/parallel。
- **Evaluator-Optimizer**：生成-评估循环，适合有明确评估标准、迭代确实能改善的场景。对应 Spring AI 的 Evaluator Optimizer。
- **Autonomous Agent**：LLM 基于环境反馈用工具的循环，带显式停止条件。对应 Pi / OpenAI Agents JS / Vercel ToolLoopAgent 的 tool loop。

## 工程启发

- **最简优先的判定链**：能用确定性代码就不要单次调用，能用单次调用就不要 workflow，能用固定 workflow 就不要自治 agent。这条链让 skill 的 Architecture Rules 有了一个权威出处，而不只是"经验上建议"。
- **simplicity / transparency / ACI 三原则**：
  - simplicity——本仓库 anti-patterns 里"过度工程 agent"的正面表述。
  - transparency——让规划步骤对人可见，对应本仓库一贯的 event 化 agent loop（Pi 的 `agent_start/turn_start/...` 事件、Vercel 的 UI message 边界）。
  - ACI——把 agent-computer interface 当公共 API 一样设计：工具描述、参数命名、用法示例、边界情况、充分测试、poka-yoke 防误用（如强制绝对路径）。这是 `context-and-tools.md` 里 Tool Description/Schema Rubric 缺的那句"为什么"。
- **框架只是起点**：要理解底层代码，不要被框架抽象掩盖——这正好支撑本仓库"架构优先、框架适配"的 skill 设计取舍（见 `analysis/04`）。

## 适用场景

- workflow（chain/routing/parallel/orchestrator/evaluator）：任务定义清晰、需要可预测性、步骤基本可枚举。
- autonomous agent：开放式问题、步骤数和路径不可预测、需要模型自主决策，且工具/环境可信。
- 单次调用 + retrieval：简单场景的默认选项，不要无脑往上加循环。
- 客服、编码 agent 是文章给的两个"agent 真正划算"的样板：交互天然对话式或产出可被自动化验证。

## 注意

- 这是高层指导文，不是框架实现。它的价值在判定与原则，落地细节仍要回到本仓库已分析的代码项目（TS 看 `02`、Java 看 `03`、Pi 看 `01`）。
- 文章强调 agent 成本更高、错误会累积，必须充分沙箱测试 + 护栏；引用时不要只引"agent 很强"，要连同"先确认 workflow 不够用"一起引。
- "framework 只作起点"不等于反对框架；本仓库的立场是框架适配但概念优先，与原文一致，不要误读成"不要用框架"。

## 对最终 skill 的影响

本轮把上述判定与原则吸收进 skill，具体改动（与 `analysis/07` 综合报告、`CHANGELOG.md` 1.1.0 一致）：

- `SKILL.md`：
  - `Architecture Rules` 增加首条"最简优先"判定：deterministic > 单次调用 > 结构化 workflow > 自治 tool loop，只有步骤不可预测且工具可信才升级到自治 agent；五种 workflow 模式术语与原文对齐。
  - `Build Workflow` 第 4 步补一句：能用固定 workflow 或单次调用就不要做自治 agent。
- `references/agent-architecture.md`：新增 `Workflow vs Agent` 小节（引用本文件）；决策表新增"开放式 / 步骤不可预测 / 工具可信 → 自治循环"行；`Loop Design` 增加 environment feedback + 显式停止条件一条。
- `references/anti-patterns.md`：强化 `Over-Engineered Agent`，明确点出"在固定 workflow 更可靠、更透明时却做自治 agent"这一具体反模式。
- `references/context-and-tools.md`：Tool Description Rubric 增加 ACI 准则——把 agent-computer interface 当公共 API 一样投入设计与测试。
- `references/source-map.md`：补记该文章快照路径与抓取日期。
