# mini-swe-agent v2 极简 Harness 分析

> 分析版本：1.0 ｜ 最后更新：2026-08-04 ｜ 来源：SWE-agent, mini-swe-agent（commit `a83fcae82d2a08f0ee0c688f9d137b3566c097f8`，详见 `analysis/SOURCE_INDEX.md`）

如果 OpenAI Codex 代表生产 harness 的宽边界，mini-swe-agent v2 就是刻意压缩后的实验基线：一个约百行的 agent class、bash action interface、线性 message history 与可替换 execution environment。它由 SWE-bench / SWE-agent 团队维护，强调模型能力增强后应重新验证复杂 ACI 是否仍然必要。

它与 `analysis/10-learn-claude-code.md` 的教学简化不同：Learn Claude Code 通过逐课增加机制解释 harness 能力谱；mini-swe-agent 则主动删掉绝大多数机制，以 benchmark、可调试 trajectory 和 sandbox portability 检验“最少 scaffold 能做到什么”。

## 核心抽象

- **Agent = query → execute → observe 的最小循环**。`DefaultAgent.step()` 直接组合 model query 与 environment execution；run loop 只处理预算、格式错误、结束和持久化。
- **Bash 是通用 action language**。模型不依赖 provider tool-calling schema，只输出一个 shell action；文件阅读、搜索、编辑、测试和提交都复用现有 CLI 生态。
- **Linear history = trajectory**。model message 与 observation 只追加到同一列表，不做隐藏状态变换，发送给模型的 history 与保存的 trajectory 高度一致，便于 debug、fine-tuning 和 benchmark 比较。
- **Stateless command execution**。每次 action 在新 subprocess 中运行，环境变量和 `cd` 不隐式延续；换成本地、Docker、bubblewrap、Singularity 等 environment 只需替换 execution adapter。
- **Harness 是可消融变量**。极简实现的目的之一是把研究注意力放回 model，并减少 benchmark 对特定工具接口的过拟合。

## 重要模式

### 单 action 协议

默认 prompt 要求每次响应恰好包含一个 bash action。一次只执行一个环境动作使 trajectory 容易解释，也降低并行 tool result 排序与部分失败的复杂度；代价是更多 model round trip。

### 异常作为 loop 控制信号

`Submitted`、`LimitsExceeded`、`FormatError` 和 interruption 都携带结构化 message，被 run loop 追加到 trajectory；当最后 message 的 role 为 `exit` 时结束。这把 termination 和错误反馈统一到模型可见历史中。

### 无状态 shell 与显式持久化

每次 `subprocess.Popen` 使用独立 process group，timeout 时终止整个 group，避免孤儿子进程。由于 shell state 不保留，模型必须在命令中显式声明 cwd/env，或把状态写入文件；这牺牲便利换取隔离和可复现性。

### Output bounding

长命令输出只保留 head/tail 并提示 agent 改用更窄命令，防止单次 observation 吞掉 context。它是比 LLM compaction 更便宜、更靠近信息源的控制点。

### Benchmark-first configuration

agent、model、environment 与 benchmark runner 分开，trajectory 保存模型成本、调用次数、配置、结束原因和 submission。相同最小 harness 可跨模型与 sandbox 批量运行，适合作为比较基线。

## 工程启发

- 在引入复杂 tool registry、planner、memory 或多 agent 前，先建一个 bash-only / linear-history baseline；如果简单 harness 已达到目标，新增机制必须用 eval 证明收益。
- harness 复杂度应随 model 版本重新消融。旧模型需要的专用工具和 prompt 补丁，可能在新模型上只增加 token、延迟和过拟合。
- 线性 trajectory 是诊断黄金基线：若生产系统做了压缩、隐藏注入或动态工具选择，至少保留一条可重建“模型实际看见什么”的审计路径。
- stateless execution 使 sandbox 替换简单，但任务确需长期 server、交互式程序或 session-local credentials 时，应显式引入 managed process/session，而不是假装无状态。
- bash-only 把能力复用交给 CLI，也把权限面扩大到整个 shell；简单接口不等于简单安全模型。

## 适用场景

- SWE-bench、ProgramBench 等批量软件工程评测与模型对比。
- 需要能一眼读懂、容易 fork、容易替换模型或 sandbox 的 coding-agent baseline。
- 验证一个专用 tool/agent scaffold 是否真正提高成功率。
- 不适合默认用于含 secrets、生产网络、不可逆 side effect 或复杂人工审批的真实工作站。

## 注意

- 项目 README 的 benchmark 成绩会随模型、数据集、配置和评测 harness 变化；本分析吸收结构，不把单一分数当 durable 结论。
- `shell=True` 与 bash-only surface 风险很高，必须放入真正 sandbox 并限制 network、filesystem、process 与 credentials。
- 线性 history 最适合单 session；长任务仍需 compaction、外部 progress 或 session rollover，不能从“简单有效”推导出“连续性不需要设计”。
- 用异常做控制流在小型 loop 中清楚，在跨进程/分布式 runtime 中需要稳定协议而非语言级 exception。

## 对最终 skill 的影响

- `skills/design-ai-agent/SKILL.md`：新增 minimal-harness baseline 与 model-upgrade ablation，要求复杂 scaffold 用 eval 证明增益。
- `skills/test-ai-agents/SKILL.md`：增加线性 trajectory baseline、跨 harness/model 联合报告和 execution adapter 一致性测试。
- `skills/review-ai-agents/SKILL.md`：提醒 bash-only 简化能力接口但扩大安全面，并检查隐藏 context transformation 是否可重建。
- `skills/build-ai-agents/references/source-map.md`：登记 mini-swe-agent commit 与核心 agent/environment/config/control-flow 文件。
- `analysis/07-overall-agent-analysis.md`：在形态光谱加入“极简 benchmark harness”，并把 harness ablation 纳入共识。

