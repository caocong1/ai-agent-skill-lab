# OpenAI《Codex as a platform: build on the open agent harness》结构化摘要

> **来源**：https://developers.openai.com/blog/codex-as-a-platform
> **发布**：2026-08-19（页面头部显示 "Aug 19, 2026"，developers.openai.com 博客索引同日；作者 Nicolas Bonamy、Derrick Choi。页面没有机器可读的日期字段）
> **抓取**：首次 2026-09-04（WebFetch，AI 辅助结构化转述）；2026-10-25 逐条复核并修正（2026-09-04 版把日期记为"待核验"、把 ARC-AGI-3 的提升归因于 harness 的工具与审批机制，两处均已更正）
> **性质声明**：本文件是**转述式结构化摘要**，不是原文镜像。数字与引语以原文为准；需要原文请访问上方官方链接。

## 核心主张

Codex 不只是用户看到的 App、CLI 或 IDE 扩展，而是一个**可构建的平台**：开源 Codex harness（GitHub 上的仓库）是所有 Codex 体验背后的引擎。开发者可以在它之上构建自己的产品，而不是把工作硬塞进一个通用聊天助手。原文同时划清边界：**开源的那一层是 harness 与集成面；模型访问与托管服务是另外的东西。**

- **Agent loop 是可复用层**：harness 承担 agent 工作中最难的部分——context 管理、工具使用、streaming、审批与失败处理。
- **开放可改造**：harness 开源后，开发者控制三样东西——**interface**（保留现有 dashboard/editor）、**context 与 tools**（包括应用自有 MCP 服务）、**operational boundaries**（agent 在哪跑、能访问什么、什么需要审批、工作如何被观察、结果如何回到业务系统的记录源）。

## 三层接入

| 层 | 适用 | 能力 |
| --- | --- | --- |
| `codex exec` | 非交互脚本、CI job、后台任务 | 一次性执行，返回结构化输出 |
| Codex SDK | 程序化集成 | start / resume / streaming agent 任务 |
| codex app-server | 嵌入产品的 agent 全生命周期 | 一个本地 Codex 进程：持久会话、事件流、审批处理，可中断工作、对外暴露工具 |

## ARC-AGI-3 数字的出处（2026-10-25 更正）

页面引用的"GPT-5.6 Sol 从 13.3% 到 38.3%、输出 token 少 6 倍"来自 OpenAI 2026-07-29 的另一篇文章（How enabling two settings tripled our scores on the ARC-AGI-3 benchmark，RHAE 指标）：用官方 harness 得 13.3%，打开**保留推理（retained reasoning）与压缩（compaction）两个 Responses API 设置**后得 38.3%。也就是说，这个提升来自**上下文管理设置**，而不是 harness 的工具、流式或审批机制。GPT-5.6 Sol 是真实模型（2026-07-09 发布，后由 GPT-6.1 Sol 接替）。

## 示例与采用方

- **Relay 示例应用**：一个虚构的货运运营 dashboard；用户点击 "Compare recovery" 一类动作，agent 经应用自有 MCP 工具调查，**改签等有后果的写操作要求人工审批**。未找到公开仓库。
- 采用方（页面自述，2026-10-25 逐条核对出处）：GitHub Copilot 的 JetBrains IDE 集成以 Codex 作为 agent 提供方（GitHub Changelog 2026-07-07，公开预览）；Cisco 在 Cloud Control 中用 Codex SDK（Cisco 博客 2026-06-02）；Thrive Holdings/Crete 的税务流程在试点中处理了 7,000 份申报、为从业者节省约三分之一时间（2026-05-27）——注意那里 Codex 是**以评测驱动、提出 PR 的改进回路**，并不是嵌入的 app-server 运行时。

## 与本仓库既有来源的关联提示

- 是 `analysis/16`（openai-codex 源码分析）的**平台化续篇**：16 号分析研究 harness 内部生命周期，本文给出把它作为**外部可复用组件**的三层接入契约。源码层面，app-server 的 10 个服务端→客户端请求方法（含全部审批请求）在 2026-08 到 2026-10 之间未变，是一个稳定的嵌入接缝；仓库里原有的长篇 app-server README 已被删除（其后同一路径出现了一份较短的说明文件），完整协议文档现在何处未能核实。
- "有后果的写操作要求审批"与 07 综合"权限在执行边界"一致；app-owned MCP 与 07 综合"用 MCP 复用外部能力、不替代宿主 runtime"呼应。
- OpenAI 另于 2026-09-10 发布了托管形态的 Agents API（"由 OpenAI 托管的 Codex harness"）。那是云托管服务，**不在本仓库范围**，这里只记一句以免读者混淆两者。
