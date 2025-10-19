# Phase 0 Research — Next.js/Node 架构

## Next.js App Router 作为本地 API Orchestrator
Decision: 采用 Next.js 15 App Router，API Routes (Route Handlers) 承担 REST 接口，使用 Edge Runtime 仅限读操作，写操作运行在 Node Runtime 以便调用本地模块、文件系统以及 Electron IPC。  
Rationale: Next.js 单体即可同时承载 UI 与 API，简化部署；Route Handlers 支持中间件、Streaming 与 Background Revalidation，满足即时反馈需求；与 Electron 集成时可通过自托管 Node 服务器。  
Alternatives considered: 独立 Express/Fastify 服务（需要手动整合 SSR 及打包流程）；保持 FastAPI（需跨语言维护）。

## 数据访问层：Prisma vs Drizzle
Decision: 选用 Prisma ORM + SQLite，结合 Prisma Accelerate 兼容未来远程托管；通过 Prisma Client 提供强类型查询。  
Rationale: Prisma 拥有成熟 CLI、迁移管理与类型自动生成，生态丰富（`@prisma/client` 可在 Electron/Next 中共用）；SQLite Driver 内置，满足本地离线。  
Alternatives considered: Drizzle ORM（轻量但关系处理与生成器生态较少）；TypeORM（历史包袱重，类型推断较弱）。

## SQLite 本地存储策略
Decision: 使用 file-based SQLite，数据库位于 `~/.parrot/workspaces/<workspaceId>.db`，Electron 打包时通过 `app.getPath('userData')` 定位；Prisma 连接串支持 `file:` 协议。  
Rationale: 满足 FR-007 的持久化需求，同时易于备份；Prisma 对 SQLite 迁移成熟。  
Alternatives considered: DuckDB（偏分析场景，不适合频繁写入）；Neon/Postgres（需额外服务，不符合离线要求）。

## 后端测试策略
Decision: 使用 Vitest 运行服务端测试（ts-node/tsx 编译），结合 Supertest 调用 Route Handlers；合约测试通过共享测试夹具对不同 `ModelProvider` 实现执行同组断言。  
Rationale: 与前端同栈工具链，Vitest 支持模拟 ESM；Supertest 对 Next Route Handler 兼容，可在测试中启动局部 handler。  
Alternatives considered: Jest（生态成熟但与 ESM/TS 配置更复杂）；直接调用 fetch（需手动 mock Request/Response）。

## 前端测试栈
Decision: 沿用 Vitest + React Testing Library 做单元/组件，用 Cypress Component Testing 覆盖拖拽图谱交互，Playwright 完成端到端场景。  
Rationale: 与 Next.js/Vite 生态兼容，拖拽/音频交互在 Cypress CT 中体验更好。  
Alternatives considered: 仅用 Playwright（端到端慢，难以覆盖细粒度状态）。

## 模型提供方调用与回退策略
Decision: 在 `packages/core/model-provider` 中定义 `ModelProvider` 接口（`generateFeedback`、`transcribe`、`generateCards`），使用 `p-queue` 控制并发；首选 Doubao-1.6（OpenAI Compatible），其次自定义 OpenAI 兼容端点，再次本地模板。  
Rationale: Promise 风格接口易于在 Route Handler 与工作线程中复用，`p-queue` 提供速率限制与重试；统一返回结构便于记录回退事件。  
Alternatives considered: 每个 provider 内部自管重试（难以统一统计）；LangChain（笨重且增加依赖）。

## Anki 导出方案（TypeScript）
Decision: 使用 `anki-apkg-export` 库生成 `.apkg` 文件，配合 `jszip` 写入媒体资源；保留 JSON 导出作为备用路径。  
Rationale: 该库纯 JS，可在 Node/Electron 中运行，支持自定义卡片模板；满足离线需求。  
Alternatives considered: 调用 Python genanki（需跨语言桥接）；依赖 AnkiConnect（需要用户额外运行 Anki）。

## 音频转写与多通道捕捉
Decision: 浏览器端优先使用 Web Speech API（在线环境），无法使用时将音频通过 `/api/ideas/transcribe` 上传，由服务端借助 `@xenova/transformers`（Whisper 模型）或外部 Doubao 语音接口进行离线推理；Electron 端可直接调用主进程的 `whisper.cpp` 绑定并将文本回传。  
Rationale: 保证桌面端离线能力，同时复用同一 API；`@xenova/transformers` 支持 Node 和浏览器 WebGPU。  
Alternatives considered: 仅用浏览器 API（离线不可用）；直接集成 Vosk（二进制较大，WebAssembly 在 Node 维护成本高）。

## 活动日志与Fallback 观测
Decision: 采用 `pino` 输出 JSON 日志，写入本地 `logs/<workspaceId>.log`，同时在数据库记录关键 fallback 事件，提供 `/api/admin/logs` SSE 接口。  
Rationale: `pino` 高性能、结构化，可在 Electron 中 tail；结合数据库记录满足 FR-008。  
Alternatives considered: Winston（灵活但性能偏低）；console.log（不利于解析）。

## 本地认证（满足 FR-006）
Decision: 将 workspace secret 使用 `keytar` 存储在系统凭据管理器；首次创建工作区时生成随机 256-bit secret，Next.js API 提供 `POST /api/auth/token` 根据 `workspaceId + secret` 签发短期 JWT（使用 `jose`）。Electron 界面读取 keytar 自动获取 token；浏览器端需用户手动输入 secret 后缓存于 IndexedDB。  
Rationale: 利用 OS keychain 实现单用户认证，兼顾未来多用户拓展。  
Alternatives considered: 简单 session cookie（缺乏本地加密存储）；无认证（违反 FR-006）。

## 数据保留策略（FR-009）
Decision: 默认无限期保留，用户可在设置中导出/删除工作区；提供 `DELETE /api/admin/workspaces/{id}` 触发备份并清理 SQLite/日志；定期执行 `VACUUM` 和日志轮换。  
Rationale: 学习数据价值高，同时提供自主管理；符合本地隐私要求。  
Alternatives considered: 到期自动清理（破坏用户长期复习）；云存档（需额外服务）。

## Electron 集成与打包
Decision: 使用 `electron-builder` 打包，主进程启动 Next.js server（生产模式 `next start`）并监听动态端口；通过自定义协议 `parrot://` 处理深链接。桌面端渲染进程加载 Next.js 前端，IPC 管理通知与文件访问。  
Rationale: `electron-builder` 支持跨平台签名，Next.js 可作为静态资源或 SSR 服务提供给 Electron；动态端口避免冲突。  
Alternatives considered: Tauri（更轻量但与现有 React 生态差异大）；保持纯浏览器（不满足 Electron 需求）。
