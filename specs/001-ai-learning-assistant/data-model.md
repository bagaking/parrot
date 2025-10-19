# Data Model — Next.js/Prisma 版本

## 概览
- 数据库：SQLite（Prisma ORM），数据库文件按 workspace 隔离（`~/.parrot/workspaces/<workspaceId>.db`）。
- 标识符：应用层使用 ULID 生成（`ulid()`），Prisma schema 提供 `@default(uuid())` 作为兜底，以防漏传。
- Prisma schema 拆分模块：`packages/data/schema.prisma`，生成的 Prisma Client 供 API Route、后台任务、Electron 主进程共享。

## 实体定义（Prisma 草案）

```prisma
// schema.prisma 片段
model Workspace {
  id             String   @id @default(uuid()) // 实际使用应用层 ULID，默认 uuid 作为兜底
  name           String   @unique @db.VarChar(64)
  secretKeyRef   String   @db.VarChar(255)
  status         WorkspaceStatus @default(ACTIVE)
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
  ideas          IdeaCapture[]
  nodes          KnowledgeNode[]
  reviewCards    ReviewCard[]
  providers      ModelProviderConfig[]
  activityLogs   ActivityLog[]
  exportJobs     ExportJob[]
}

enum WorkspaceStatus {
  ACTIVE
  ARCHIVED
  DELETED
}

model IdeaCapture {
  id                     String   @id @default(uuid())
  workspaceId            String
  channel                CaptureChannel
  content                String   @db.Text
  rawPayload             Json?
  language               String   @db.VarChar(12) @default("auto")
  capturedAt             DateTime @default(now())
  aiTags                 Json     @default("[]")
  status                 IdeaStatus @default(DRAFT)
  transcriptionConfidence Float?
  lastFeedbackId         String?
  feedbackSnapshots      IdeaFeedbackSnapshot[]
  edges                  IdeaNodeEdge[]
  referencesFrom         IdeaReference[] @relation("referencesFrom")
  referencesTo           IdeaReference[] @relation("referencesTo")
  reviewCards            ReviewCard[] @relation("CardSources", references: [id])

  Workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
}

enum CaptureChannel {
  TEXT
  CLIPBOARD
  AUDIO
}

enum IdeaStatus {
  DRAFT
  CLASSIFIED
  LINKED
  ARCHIVED
}

model IdeaFeedbackSnapshot {
  id          String   @id @default(uuid())
  ideaId      String
  providerId  String
  summary     String   @db.Text
  labels      Json     @default("[]")
  createdAt   DateTime @default(now())

  Idea    IdeaCapture        @relation(fields: [ideaId], references: [id], onDelete: Cascade)
  Provider ModelProviderConfig @relation(fields: [providerId], references: [id], onDelete: Cascade)
}

model KnowledgeNode {
  id          String   @id @default(uuid())
  workspaceId String
  title       String   @db.VarChar(128)
  description String?  @db.Text
  parentId    String?
  nodeType    KnowledgeNodeType
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  sequence    Int      @default(0)

  Workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
  Parent    KnowledgeNode? @relation("NodeHierarchy", fields: [parentId], references: [id])
  Children  KnowledgeNode[] @relation("NodeHierarchy")
  edges     IdeaNodeEdge[]
}

enum KnowledgeNodeType {
  TOPIC
  SUBTOPIC
  REFERENCE
}

model IdeaNodeEdge {
  id          String @id @default(uuid())
  ideaId      String
  nodeId      String
  relationship NodeRelationship @default(BELONGS_TO)
  createdAt   DateTime @default(now())

  Idea IdeaCapture   @relation(fields: [ideaId], references: [id], onDelete: Cascade)
  Node KnowledgeNode @relation(fields: [nodeId], references: [id], onDelete: Cascade)

  @@unique([ideaId, nodeId])
}

enum NodeRelationship {
  BELONGS_TO
  SUPPORTS
  CONTRASTS
}

model IdeaReference {
  id             String @id @default(uuid())
  sourceIdeaId   String
  targetIdeaId   String
  relationship   IdeaReferenceType
  createdAt      DateTime @default(now())

  Source IdeaCapture @relation("referencesFrom", fields: [sourceIdeaId], references: [id], onDelete: Cascade)
  Target IdeaCapture @relation("referencesTo", fields: [targetIdeaId], references: [id], onDelete: Cascade)

  @@unique([sourceIdeaId, targetIdeaId, relationship])
}

enum IdeaReferenceType {
  FOLLOW_UP
  CITATION
  PREREQUISITE
}

model ReviewCard {
  id               String   @id @default(uuid())
  workspaceId      String
  sourceIdeaIds    Json     @default("[]")
  front            String   @db.Text
  back             String   @db.Text
  hints            Json     @default("[]")
  tags             Json     @default("[]")
  generationStatus GenerationStatus @default(PENDING)
  fallbackSource   FallbackSource?
  createdAt        DateTime @default(now())
  updatedAt        DateTime @updatedAt
  schedule         ReviewSchedule?
  reviewLogs       ReviewSessionLog[]

  Workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
}

enum GenerationStatus {
  PENDING
  READY
  FALLBACK
  REJECTED
}

enum FallbackSource {
  DOUDAO
  OPENAI
  TEMPLATE
}

model ReviewSchedule {
  id             String @id @default(uuid())
  cardId         String @unique
  intervalMinutes Int
  dueAt          DateTime
  easeFactor     Float
  streak         Int    @default(0)
  lastReviewedAt DateTime?

  Card ReviewCard @relation(fields: [cardId], references: [id], onDelete: Cascade)
}

model ReviewSessionLog {
  id        String @id @default(uuid())
  cardId    String
  outcome   ReviewOutcome
  reviewedAt DateTime @default(now())
  notes     String? @db.Text

  Card ReviewCard @relation(fields: [cardId], references: [id], onDelete: Cascade)
}

enum ReviewOutcome {
  AGAIN
  HARD
  GOOD
  EASY
}

model ModelProviderConfig {
  id          String @id @default(uuid())
  workspaceId String
  name        String
  providerType ProviderType
  priority    Int
  baseUrl     String?
  apiKeyRef   String?
  maxTokens   Int?
  timeoutSeconds Int @default(30)
  enabled     Boolean @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  stats       ModelProviderStat[]

  Workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)

  @@unique([workspaceId, priority])
}

enum ProviderType {
  DOUDAO
  OPENAI_COMPAT
  LOCAL_TEMPLATE
}

model ModelProviderStat {
  id          String @id @default(uuid())
  providerId  String
  windowStart DateTime
  successCount Int    @default(0)
  failureCount Int    @default(0)
  avgLatencyMs Float  @default(0)

  Provider ModelProviderConfig @relation(fields: [providerId], references: [id], onDelete: Cascade)
}

model ActivityLog {
  id          String @id @default(uuid())
  workspaceId String
  actor       String
  action      String
  payload     Json
  createdAt   DateTime @default(now())

  Workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
}

model ExportJob {
  id          String @id @default(uuid())
  workspaceId String
  jobType     ExportJobType
  status      ExportJobStatus @default(QUEUED)
  requestedAt DateTime @default(now())
  completedAt DateTime?
  resultPath  String?
  errorMessage String?

  Workspace Workspace @relation(fields: [workspaceId], references: [id], onDelete: Cascade)
}

enum ExportJobType {
  ANKI_APKG
  JSON
}

enum ExportJobStatus {
  QUEUED
  RUNNING
  SUCCESS
  FAILED
}
```

## 约束与校验摘要
- 所有跨实体关系设置 `onDelete: Cascade`，并通过 API 层防止误删。
- `KnowledgeNode` 深度限制在 Route Handler 中校验（≤5 层），并引入 `sequence` 字段用于排序。
- 利用 Prisma 中间件统一写入/更新审计字段；在写操作前对 `IdeaCapture.content` 做 XSS 清洗。
- `ReviewSchedule` 更新通过事务包裹，确保卡片状态与调度同步。
- 建立 SQLite 索引：`CREATE INDEX idx_idea_capture_channel_time ON IdeaCapture(channel, capturedAt);`、`CREATE VIRTUAL TABLE IdeaSearch USING fts5(id, content);` 并通过触发器同步。

## 状态流转
- `IdeaCapture`: `DRAFT → CLASSIFIED → LINKED → ARCHIVED`，AI 回调更新状态，手动归档会软删除。
- `ReviewCard`: `PENDING → READY`（AI 成功）或 `FALLBACK`（模板）→ 可被用户标记为 `REJECTED` 并回退。
- `Workspace`: `ACTIVE → ARCHIVED → DELETED`，删除前执行备份与数据清理。

## 前后端共享类型
- 在 `packages/core/domain` 导出 `zod` schema（与 Prisma 相互生成）用于 API 请求/响应校验；前端通过 `openapi-typescript` 生成客户端类型。

## 数据迁移与发布
- 使用 `prisma migrate dev` 管理 schema 变更，Electron 打包前运行 `prisma generate`。
- 提供 `packages/data/seeds.ts` 生成演示数据，便于演示三条捕捉记录、一个知识图谱与若干卡片。
