# Anthropic《How we built Claude Code auto mode: a safer way to skip permissions》结构化摘要

> **来源**：https://www.anthropic.com/research/claude-code-auto-mode（原 `/engineering/claude-code-auto-mode`，现 308 重定向至此）
> **发布**：2026-03-25（作者 John Hughes）
> **抓取**：首次 2026-09-04（WebFetch，AI 辅助结构化转述）；2026-10-25 逐条复核（正文自 2026-09-02 以来未变），并补记发布后的后续进展（见文末）
> **性质声明**：本文件是**转述式结构化摘要**，不是原文镜像。数字与引语以原文为准；需要原文请访问上方官方链接。

## 问题背景

Claude Code 默认对命令与文件修改要求人工审批，但用户对 93% 的提示都直接放行——**审批疲劳**让人不再细看自己批了什么（2026-08-07 的后续文章用更晚的数据给出 97%）。既有替代项构成糟糕的取舍：sandboxing 安全但维护成本高（一旦需要网络/宿主访问就碎），`--dangerously-skip-permissions` 则拆掉全部护栏。动机案例来自内部事故记录：误读指令删远程 git 分支、把工程师的 GitHub auth token 上传到内部集群、尝试生产数据库迁移。

**威胁模型**：原文列出四类——过度积极（overeager）、诚实的失误、prompt injection、失准（misaligned）的模型；分类器针对前两类调校。

## 两层防御

1. **输入层**——服务端 prompt-injection 探针，在工具输出（文件读取、web fetch、shell 输出、外部工具响应）进入上下文之前扫描，注入一条警告，要求 agent 以怀疑态度对待可疑内容并重新锚定用户意图。
2. **输出层**——transcript 分类器（跑在 Sonnet 4.6 上），在每个动作执行前评估，两阶段：先一个**被要求"宁可错杀"的单 token 快筛**，只有被 flag 的动作才进入 CoT 推理；第二阶段的 prompt 几乎全部 cache 命中自第一阶段。原文把这种动作级拦截定位为与思维链监控互补，而不是替代。

## 三级权限流

- **Tier 1**：固定的安全工具白名单（读、搜索、导航，以及 todo 与 plan 模式切换）加用户设置。关键细节：**进入 auto mode 时收回授予任意代码执行的 blanket 规则**（shell 访问、python/node 等通配解释器、包管理器 run 命令），否则分类器根本看不到危险命令。原文承认这份收回清单是尽力而为、必然不全；窄规则照常保留。
- **Tier 2**：项目内文件写/编辑**跳过分类器**——可经版本控制审查。
- **Tier 3**：一切有真实下行风险的动作（shell 命令、web fetch、外部工具集成、subagent spawn、项目外操作）都交给分类器。

## 分类器设计不变量

- **Reasoning-blind**：分类器只看到用户消息与裸工具调用；assistant 文字、工具输出、连同工具调用的描述都被剥掉。这防止执行 agent 自我合理化绕过检查，也**结构性阻断**向分类器的 prompt injection。原文给出了这个选择的**输入消融**：加入 assistant 文字与工具结果会让效果变差；只给工具调用时漏判率最低，但丢掉了"用户意图"这个锚——所以最终是"用户消息 + 裸工具调用"。
- **三个可定制槽位**：environment（信任边界，默认：当前 git 仓库）、block 规则（20+ 条，分四类——销毁/外泄、降低安全姿态、跨信任边界、绕过审查或影响他人）、allow 例外（窄口径，如来自仓库 manifest 的包、标准凭据流程、push 到当前会话的工作分支）。`claude auto-mode defaults` 可打印完整默认清单。
- **按真实影响评估，不按表面文本**：写入文件的 payload、`&&` 串接、动态拼装的命令按一个整体评估。
- **默认按意图 deny**：agent 自主选择的一切都是未授权的，除非用户明说过；"清理我的分支"不授权批量远程删除，一个问题不是指令。
- Block 例子：范围升级（删远程分支）、凭据探查（grep 环境变量找 token）、agent 自拟参数（猜一个 job 然后取消）、经 Gist 外泄、绕过安全检查（部署时加 skip-verification flag）。
- **多 agent 交接**：subagent 委派时分类器可拒绝；返回时审阅子 agent 的完整动作历史，但只前置一条安全警告，不丢弃结果。

## 拒绝路径与熔断

拒绝以工具结果返回，指示 agent "善意对待边界"、另寻更安全的路径，而不是绕行。兜底：**连续 3 次或累计 20 次拒绝后停下**，升级给人工（headless `claude -p` 模式下直接终止）。

## 结果（诚实的取舍）

| 数据集 | Stage 1 | 全流水线 |
| --- | --- | --- |
| 真实流量（n=10,000） | 8.5% FPR | **0.4% FPR** |
| 真实过度激进集（n=52） | 6.6% FNR | **17% FNR** |
| 合成外泄集（n=1,000） | 1.8% FNR | 5.7% FNR |

多数漏判发生在分类器**看出危险但误判"用户的同意是否覆盖该动作的爆炸半径"**（"清理这个 PR"没提 force-push）：它找到了"看起来像授权"的证据就停下，没有继续核对这份同意的覆盖范围；原文说提示词工程至今没能修好这一点。作者坦率地框定：相对 skip-permissions 是大改善，但相对认真的人工审查可能是退步——auto mode 在高风险基础设施上**不是人工判断的即插替代**。

## 发布后的后续进展（2026-10-25 补记，非原文内容）

- 2026-08-07 的后续文章（claude.com，2026-10-22 有更新说明）：auto mode 自 2026-08-14 起成为 Pro / Max / Team 计划的默认模式；`python:*` 这类宽泛 allow 规则在 auto mode 下被自动搁置而无需改设置；一项 1,053 名付费测试者参与的研究中，人对危险命令的拦截率为 13.6%，auto mode 为 89%；经 Apollo Research 红队后漏判率由 12% 降到 7%；Trajectory Labs 的测试中 720 次 prompt injection 无一成功；新增硬拒绝、git push 目标的公开/私有检查、破坏性 git 命令前先跑 `git status`。均为厂商自述。
- 第三方反证：Embrace The Red（2026-08-26）在小样本上对 auto mode 下的 Opus 5 报告了 60–80% 的攻击成功率，手法是诱导把 WebFetch 换成 curl、以及植入一个遮蔽 Python 标准库的 `struct.py`。
- "How we contain Claude across products"（2026-05-25）把 auto mode 定位为沙箱之内的一层防御。

## 与本仓库既有来源的关联提示

- 与 `analysis/18`（DeepSeek Harness）的**单调 ToolGuard**（返回类型不表达 allow）互补：机械边界保证"不重开"，本文解决"机械边界之上高频人工审批的疲劳面"。
- "进入 auto mode 收回 blanket 规则"是 secure-ai-agents 已有"工具自述不是授权依据"的镜像：**策略聚合本身会掩盖可执行面**。
- reasoning-blind 评审上下文与 07 综合"权限在执行边界、敏感上下文走 typed context"同一条纪律的评审侧应用。
