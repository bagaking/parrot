# Quickstart — Next.js + Electron 版本

## 前置条件
- Node.js 20.x（含 pnpm 9）
- SQLite3 CLI（用于调试，可选）
- FFmpeg（音频转码）
- Python 3.11 可选（若需使用 whisper.cpp 预处理脚本）
- Doubao-1.6 或兼容 OpenAI API 的接口凭证
- macOS/Windows 桌面环境（Electron 包目标平台）

## 初始设置
1. **切换分支**
   ```bash
   git checkout -b 001-ai-learning-assistant
   ```
2. **安装依赖**
   ```bash
   pnpm install
   ```
3. **环境变量**
   ```bash
   cp apps/web/.env.example apps/web/.env.local
   cp apps/desktop/.env.example apps/desktop/.env
   cp packages/core/.env.example packages/core/.env
   ```
   - `NEXTAUTH_SECRET`、`WORKSPACE_SEED_NAME`、`DOUBAO_API_KEY`、`OPENAI_FALLBACK_URL` 等根据需要填写。
4. **数据库迁移**
   ```bash
   pnpm prisma migrate dev --schema=packages/data/schema.prisma
   pnpm prisma generate --schema=packages/data/schema.prisma
   ```
5. **初始化工作区**
   ```bash
   pnpm tsx scripts/dev/init-workspace.ts --name "Default"
   ```
   脚本会生成 workspace secret 并使用 `keytar` 写入系统凭据，同时打印一次性查看的 secret。

## 启动服务
- **开发模式**
  ```bash
  pnpm dev      # 并行启动 Next.js + Electron（turbo 或 nx）
  ```
  - Next.js: http://localhost:3000
  - Electron 会自动打开桌面窗口

- **仅 Web 调试**
  ```bash
  pnpm --filter @parrot/web dev
  ```

- **转写工作线程（可选）**
  ```bash
  pnpm tsx scripts/dev/start-transcriber.ts
  ```

## 测试
```bash
pnpm test          # 运行 Vitest（含前后端单元测试）
pnpm test:ct       # Cypress Component 测试
pnpm test:e2e      # Playwright 端到端
```

## 手动校验流程
- **多通道捕捉**：在 web/Electron 界面依次提交文本、剪贴板、音频（.m4a），观察 1.5 秒内生成标签。
- **知识图谱**：创建主题节点，拖拽点子到该节点，刷新确认 `/api/graph/nodes` 结构正确。
- **卡片生成**：选择 ≥3 条点子触发卡片生成，检查回退日志及导出队列。
- **导出**：调用 “导出为 Anki” 并在 `~/.parrot/workspaces/<id>/exports/` 中确认 `.apkg` 文件。

## 故障排查
- 如果 Next.js API 报数据库连接错误，检查 `DATABASE_URL=file:~/.parrot/workspaces/<id>.db` 是否存在。
- 若 Doubao 请求延迟过高，调整 `MODEL_MAX_CONCURRENCY` 或切换本地模板。
- Electron 打包失败可通过 `pnpm run build:desktop --publish never --dir` 查看日志。
- Web Speech API 不可用时，确保转写脚本已启动或启用 Doubao 语音接口配置。
