# Parrot

Parrot is a planned local-first AI learning assistant. The first milestone is
defined around fast idea capture, knowledge-graph organization, and Anki card
generation with model fallback behavior.

This repository is currently a specification and planning workspace, not a
released product or runnable application.

## Current Status

- Product scope is documented under `specs/001-ai-learning-assistant/`.
- The intended implementation shape is a TypeScript monorepo with a Next.js web
  app, an Electron desktop wrapper, shared packages, Prisma, and SQLite.
- The repository does not currently include `package.json`, `apps/`, or
  `packages/` application source trees.
- The quickstart commands in the feature spec describe the intended application
  workflow after implementation scaffolding exists; they are not yet verified
  against this tree.

## Technology And Commands

Planned product stack:

- TypeScript 5.x, Node.js 20 LTS, Next.js App Router, React
- Prisma ORM with SQLite for local persistence
- TanStack Query and Zustand for client state
- OpenAI-compatible model interface with Doubao-compatible and local fallback
  paths
- Electron for the desktop shell
- Anki package export support

Current repository commands:

```bash
make validate
make init
make codex_home
make codex
make cc_codex
```

Planned application commands, once the implementation exists:

```bash
pnpm install
pnpm dev
pnpm test
pnpm build
```

## Validation

Current validation is limited to reviewing the specification artifacts:

- `specs/001-ai-learning-assistant/spec.md`
- `specs/001-ai-learning-assistant/plan.md`
- `specs/001-ai-learning-assistant/data-model.md`
- `specs/001-ai-learning-assistant/contracts/openapi.yaml`
- `specs/001-ai-learning-assistant/quickstart.md`

Run `make validate` to check that the required spec files exist, the OpenAPI
YAML parses, and the repository still presents itself as a spec-only workspace.

No automated product test suite is present in the repository yet. The intended
future validation surface includes unit tests, API tests, component tests, and
end-to-end tests after the application is scaffolded.

## Product Boundary

Parrot should not be treated as a published or production-ready learning
assistant yet. The repository does not currently provide:

- a runnable browser or desktop application
- persisted local workspaces
- model-provider integrations
- speech transcription
- Anki export
- security, privacy, or data-retention guarantees beyond the written plan

Use the existing documents as product intent and implementation guidance, not as
evidence that those features are already shipped.
