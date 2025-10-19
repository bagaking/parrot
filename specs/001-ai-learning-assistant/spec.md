# Feature Specification: AI 学习助理首个里程碑

**Feature Branch**: `001-ai-learning-assistant`  
**Created**: 2025-10-18  
**Status**: Draft  
**Input**: User description: "做一个 AI 学习助理的站点, 提供多通道点子捕捉、知识脉络整理、自动生成 Anki 卡片与间隔复习安排。 首个里程碑聚焦桌面/浏览器端体验，使用本地 FastAPI 服务负责数据与调 度，前端提供即时反馈。 AI模块采用可替换的语言模型接口（默认调用 OpenAI 兼容 API，可配置本地推理, 第一个版本接入 doubao-1.6），并包含明确的回退路径。 用 ts 开发"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 多通道点子快速捕捉 (Priority: P1)

自学者需要在桌面浏览器中快速捕捉学习点子（文本、剪贴板、语音转文本）并立即获得 AI 反馈，以免灵感丢失。

**Why this priority**: 无摩擦的输入是后续知识整理与复习的前提，决定了工具是否可用。

**Independent Test**: 通过浏览器 UI 在 30 秒内提交三种来源的点子并收到响应提示，所有内容在本地服务持久化。

**Acceptance Scenarios**:

1. **Given** 浏览器已连接本地 FastAPI 服务，**When** 用户粘贴一段文本并点击保存，**Then** 服务持久化条目并返回实时分类标签建议。
2. **Given** 用户上传语音片段，**When** 前端触发语音识别，**Then** FastAPI 通过模型接口返回文本以及置信度提示。

---

### User Story 2 - 知识脉络整理与可视化 (Priority: P1)

学习者希望将已捕捉的点子整理为主题、子主题与引用链路，系统需提供图谱视图与上下文笔记展示。

**Why this priority**: 没有结构化组织无法驱动后续复习计划，影响知识沉淀质量。

**Independent Test**: 在知识图谱界面选择任意点子可查看其主题、相关条目与AI建议，更新操作即时反映在前端和数据库。

**Acceptance Scenarios**:

1. **Given** 已存在多个点子，**When** 用户创建新主题并拖拽点子到主题下，**Then** FastAPI 更新关系并返回成功状态，前端刷新结构视图。
2. **Given** 用户查看某点子，**When** 请求相关引用，**Then** 服务返回按时间排序的关联记录和推荐补充项。

---

### User Story 3 - 自动生成 Anki 卡片与复习计划 (Priority: P2)

学习者希望系统自动生成高质量的 Anki 卡片，包含间隔复习日程与回退策略，支持导出为 .apkg 或 JSON。

**Why this priority**: 直接影响复习效率，是产品的核心差异点但依赖前两项数据。

**Independent Test**: 选择至少三个点子批量生成卡片，系统输出建议卡面、复习计划，并允许下载导出；卡片可回滚为手动编辑状态。

**Acceptance Scenarios**:

1. **Given** 用户在知识图谱中选择多条记录，**When** 请求生成卡片，**Then** FastAPI 使用 doubao-1.6 接口返回前后卡面、标签和初始复习间隔。
2. **Given** 卡片生成完成，**When** 模型调用失败，**Then** 系统启用回退策略（最近成功配置或模板）并记录在活动日志中。

---

### Edge Cases

- What happens when FastAPI 服务无法连接模型接口 (网络或本地推理离线)?
- How does system handle 冲突的主题归类（同一条目被多个主题持久引用）?
- Which invariants must remain true across every implementation of language-model 接口?

## Requirements *(mandatory)*

*Constitution alignment*: Document extension seams, injected dependencies, and canonical sources for shared rules.

### Functional Requirements

- **FR-001**: System MUST 支持浏览器端的文本、剪贴板、语音转文本三种点子输入渠道。
- **FR-002**: System MUST 通过 FastAPI 提供点子持久化、主题管理、关系图谱、卡片生成等 REST 接口。
- **FR-003**: Users MUST be able to 在前端查看模型即时反馈（分类、标签、建议操作），延迟 < 1.5 秒。
- **FR-004**: System MUST 允许切换语言模型提供方（默认 OpenAI 兼容 API，支持 doubao-1.6、本地推理）。
- **FR-005**: System MUST 生成并管理 Anki 间隔复习计划，支持导出与回滚。
- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: 是否需要账号/本地用户体系?]
- **FR-007**: System MUST persist all captured data to [NEEDS CLARIFICATION: 数据存储介质，SQLite/文件/其他?]
- **FR-008**: System MUST log fallback activation events including root cause and recovery path。

*Example of marking unclear requirements:*

- **FR-009**: System MUST retain user data for [NEEDS CLARIFICATION: 数据保留策略]

### Key Entities *(include if feature involves data)*

- **IdeaCapture**: 点子内容、来源渠道、捕捉时间戳、AI 标签、关联主题。
- **KnowledgeNode**: 主题或子主题节点，包含描述、父节点引用、相关 Idea 列表。
- **ReviewCard**: Anki 卡片结构，包含前后卡面、复习间隔、来源 Idea IDs、生成状态、回退标记。
- **ModelProvider**: 模型接口配置（类型、API 密钥、速率限制、回退优先级）。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 用户可在单次会话中捕捉 ≥ 10 条点子且平均响应时间 ≤ 1.5 秒。
- **SC-002**: 知识图谱操作（新增主题、关联点子）成功率 99% 且延迟 ≤ 2 秒。
- **SC-003**: 至少 80% 自动生成的 Anki 卡片通过用户审阅无需大幅调整。
- **SC-004**: 回退路径触发后仍然保证卡片生成流程成功率 ≥ 95%。
