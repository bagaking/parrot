# Implementation Plan: AI 学习助理首个里程碑

**Branch**: `001-ai-learning-assistant` | **Date**: 2025-10-19 | **Spec**: `/Users/bytedance/proj/priv/bagaking/parrot/specs/001-ai-learning-assistant/spec.md`
**Input**: Feature specification from `/specs/001-ai-learning-assistant/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. Document the workflow in `.specify/templates/commands/plan.md` once the command template is created.

## Summary

Local-first AI 学习助理首个里程碑将交付桌面/浏览器统一体验：以 Next.js（Node/TypeScript）应用同时提供前端 UI 与 API Routes，支撑多通道点子捕捉、知识图谱整理与即时 AI 反馈；后端模块通过可插拔语言模型接口（首发对接 doubao-1.6 并兼容 OpenAI 风格 API）与调度管线生成 Anki 卡片并提供回退策略，同时为后续 Electron 封装预留同构 API。

## Technical Context

**Language/Version**: TypeScript 5.x (Next.js full-stack), Node.js 20 LTS  
**Primary Dependencies**: Next.js 15 (App Router), React 18, Prisma ORM, SQLite, TanStack Query, Zustand, openai-compatible SDK, anki-apkg-export  
**Storage**: SQLite (file-based) via Prisma with drizzle-like typed schema (Prisma Client)  
**Testing**: Vitest + React Testing Library; Supertest + MSW for API routes; Playwright for integration/E2E; Cypress CT for drag-drop flows  
**Target Platform**: Desktop browsers (Chrome, Edge) + Electron shell consuming local Next.js server  
**Project Type**: Monorepo with Next.js app (`apps/web`) and Electron wrapper (`apps/desktop`), shared packages in `packages/`  
**Performance Goals**: Idea capture to feedback round-trip <1.5s p95; knowledge graph updates <2s; model fallback activation recorded within 200ms overhead  
**Constraints**: 需支持模型切换至本地推理的离线能力；API Routes 可嵌入 Electron 主进程；workspace secret 必须受操作系统凭据保护；数据仅存于本地文件系统  
**Scale/Scope**: Single-user desktop usage initially (≤5 concurrent sessions), <10k ideas per workspace, readiness for sync expansion in later milestones

## Constitution Check

- `Single Responsibility Modules`: 功能按用户故事映射到 Next.js 路由/服务模块——`apps/web/app/api/ideas`（点子捕捉）、`app/api/graph`（知识图谱）、`app/api/reviews`（复习计划）、`packages/core/model-provider`（模型调度）；UI 端保留特性切片 `apps/web/src/features/*`。若某模块职责溢出需在复杂度表登记重构时间。
- `Open-Closed Extension Points`: `ModelProvider` 与 `StorageGateway` 定义于 `packages/core`，新增模型或存储时通过扩展实现接入，避免修改主服务。Next.js Route Handler 保持稳定接口；如需调整，将附上迁移步骤于 Phase 1 文档。
- `Substitution Contract Integrity`: `ModelProvider`、`FallbackStrategy`、`CardExporter` 均声明前置/后置条件，使用 Vitest contract test 覆盖 doubao、openai-compatible、本地模板等实现，确保替换无副作用。
- `Focused Interface Boundaries`: API 路径按 persona 分离——捕捉前端消费 `/api/ideas/*`，知识图谱前端消费 `/api/graph/*`，复习面板消费 `/api/reviews/*`，管理端独立 `/api/admin/providers`。若某消费端忽略两个以上操作，将拆分路由或提供特定 facade。
- `DRY Dependency Inversion`: 共用校验与调度逻辑沉淀在 `packages/core/domain`，前端通过自动生成的 TypeScript 客户端（OpenAPI/typed client）调用，避免重复 fetch。Electron 主进程仅注入接口，不直接依赖实现。
- `Design Excellence Standards`: 依旧采用领域命名（IdeaCapture 等），每个包/模块开头提供 docstring 或 README 说明职责、协作者、约束；Phase 1 将补充 API 时序图与模型 fallback 时序草图。

*Phase 1 Review Placeholder*: 完成新架构的设计输出后需再次核对宪法守则，当前标记为待复查。

## Project Structure

### Documentation (this feature)

```
specs/001-ai-learning-assistant/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### Source Code (repository root)

```
apps/
├── web/                 # Next.js App Router 应用
│   ├── app/             # UI + Route Handlers (API)
│   ├── src/
│   │   ├── features/
│   │   │   ├── capture/
│   │   │   ├── graph/
│   │   │   └── review/
│   │   ├── components/
│   │   ├── hooks/
│   │   └── lib/
│   └── tests/
│       ├── unit/
│       ├── integration/
│       └── e2e/
├── desktop/             # Electron 主/渲染进程代码
│   ├── src/
│   ├── preload/
│   └── tests/

packages/
├── core/                # 领域模型、模型提供方、调度逻辑
├── data/                # Prisma schema & 数据访问层
└── ui/                  # 可共享 UI 组件（可选）

scripts/
└── dev/                 # 启动、打包、迁移脚本
```

**Structure Decision**: 采用单一 Next.js 应用承载 UI + API，再由 Electron 壳层包裹，以 `packages/*` 抽离领域逻辑，确保桌面与浏览器端共享同一服务端接口并满足本地化部署需求。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
