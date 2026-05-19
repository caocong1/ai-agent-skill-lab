# Claude Review and Applied Changes

本轮使用 Claude Code 通过 `ccw cli --tool claude --mode analysis --rule analysis-review-architecture` 对项目文档和 `skills/build-ai-agents` 进行只读评审。评审范围排除了 `raw/repos` 上游源码树，聚焦本项目生成的 README、analysis、raw/docs 和 skill 文件。

## Claude 的主要结论

Claude 认为第一版 skill 对“新建 AI agent 功能”已经比较完整，但 frontmatter 宣称支持 review，而主工作流实际上偏 build-only。高优先级缺口包括：

- 缺少 build / extend / review 模式选择。
- 缺少审查已有 agent 代码的独立 workflow。
- 缺少任意代码库里的 agent 构件定位启发式。
- 缺少 review report 和 remediation plan 的输出契约。
- 缺少 agent 反模式 catalog。
- 缺少集中化的 security/threat reference。
- 缺少 review 完成定义和 prompt/tool 改动前后的 eval snapshot 要求。

## 已采纳修改

- `SKILL.md` 新增 `Mode`、`Review Workflow`、`Deliverables` 和 `Definition of Done`。
- `SKILL.md` 将原 `Mandatory Checks` 改成 `Dual-Use Rubric`，同时服务 build 和 review。
- `agent-architecture.md` 扩展决策表，加入 deterministic code、streaming UI、多租户、可逆 side effects、context overflow 等场景。
- 新增 `review-playbook.md`，提供 TS/Java/raw-SDK 定位启发式、severity/impact/effort 分级、Review Report 模板和 Remediation Plan 模板。
- 新增 `anti-patterns.md`，覆盖 permission-in-prompt-only、unbounded loop、secrets in prompt、god agent、UI/model message bleed、no agent tests 等问题。
- 新增 `security-and-safety.md`，集中 agent threat model 和安全审查清单。
- 新增 `context-and-tools.md`，集中 prompt/context、compaction、retrieval、tool description/schema 质量标准。
- `source-map.md` 新增 portability 和版本新鲜度 caveat。
- README 和 skill 设计文档改为明确支持“新建实现 + 既有代码审查优化”双用途。

## 暂不采纳或延后

- 没有删除 `SOURCE_INDEX.md`、`PROFESSIONAL_LINKS.md` 与 `source-map.md` 的重复链接，因为它们服务不同层级：lab acquisition history、专业阅读入口、skill 内证据地图。已加 canonical source map 说明以降低维护风险。
- 没有把 Claude 原始完整输出逐字保存，避免项目文档膨胀；本文件记录可追踪的结论和实际改动。

## 验证

- `quick_validate.py` 校验通过：`Skill is valid!`
- 扫描 `README.md`、`analysis/`、`raw/docs/`、`skills/build-ai-agents/`，未发现脚手架占位文本残留。
