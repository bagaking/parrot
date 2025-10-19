<!--
Sync Impact Report
Version: 0.0.0 → 1.0.0
Modified Principles:
- [PRINCIPLE_1_NAME] → Single Responsibility Modules
- [PRINCIPLE_2_NAME] → Open-Closed Extension Points
- [PRINCIPLE_3_NAME] → Substitution Contract Integrity
- [PRINCIPLE_4_NAME] → Focused Interface Boundaries
- [PRINCIPLE_5_NAME] → DRY Dependency Inversion
Added Sections: None
Removed Sections: None
Templates requiring updates:
- .specify/templates/plan-template.md ✅ updated
- .specify/templates/spec-template.md ✅ updated
- .specify/templates/tasks-template.md ✅ updated
Follow-up TODOs: None
-->

# Parrot Constitution

## Core Principles

### Single Responsibility Modules
- Every production module, class, and function MUST map to exactly one domain capability or user story recorded in `plan.md`.
- When an artifact spans multiple capabilities or exceeds 150 lines of mixed concerns, it MUST be split into collaborators before merge or justified in the plan's complexity table with a refactor owner and date.
- Rationale: Focused units keep change blast radius tight, expose duplicated behavior early, and preserve design clarity.

### Open-Closed Extension Points
- Stable modules (imported by more than one feature or released previously) MUST remain closed for modification; extend behavior through new implementations, composition, or configuration first.
- Any unavoidable change to a stable module MUST ship with a migration strategy in the spec or plan, including compatibility guarantees and rollback steps approved by a maintainer.
- Rationale: Protecting stable seams safeguards consumers and enforces extension-first design discipline.

### Substitution Contract Integrity
- Polymorphic abstractions MUST declare explicit preconditions, postconditions, and invariants in specs or docstrings; every implementation MUST honor them.
- Contract tests MUST exercise all implementations against the same scenario set before release; failing to supply these tests blocks the merge.
- Rationale: Verified contracts ensure derived types can always replace their abstractions without surprising downstream callers.

### Focused Interface Boundaries
- Public interfaces MUST expose only operations required by a single consumer persona; if a consumer omits more than two operations, split the interface or provide a thinner facade.
- Interface definitions MUST document ownership, dependencies, expected change cadence, and review cadence inside the plan/spec to keep collaboration explicit.
- Rationale: Narrow boundaries prevent accidental coupling and keep APIs expressive yet minimal.

### DRY Dependency Inversion
- Shared rules, validations, and data transformations MUST live in canonical modules; duplicated logic over 10 contiguous lines or repeated branching MUST be extracted before merge.
- High-level modules MUST depend on interfaces or abstract types, binding to concrete implementations only at composition roots or wiring modules.
- Rationale: Centralized knowledge and inverted dependencies maximise reuse, testability, and long-term design elegance.

## Design Excellence Standards
- Use domain language in naming; placeholder or abbreviated names are forbidden in production code and specifications.
- Every new module MUST start with a brief docstring describing its purpose, collaborators, and invariants; update the docstring whenever responsibilities change.
- Provide lightweight architecture sketches (diagram, sequence, or structured text) in specs for new extension points or dependency inversions; attach links in plan/spec files.
- Code reviews MUST evaluate readability, composition, and stylistic coherence alongside functional correctness; reviewers reject contributions that lower overall design taste.

## Delivery Workflow & Quality Gates
1. **Research & Plan**: During Phase 0/1 work, complete the Constitution Check in `plan.md`, mapping responsibilities, extension seams, and dependency boundaries for each planned artifact.
2. **Design Sign-off**: Before implementation, confirm the spec captures invariants for polymorphic abstractions and documents interface owners and change cadence.
3. **Implementation & Testing**: Implement DRY abstractions, wire dependencies via composition roots, and author contract tests that prove substitutability and reuse. Maintain docstrings in lockstep with code.
4. **Review & Release**: Every PR MUST link back to the relevant plan/spec sections, highlight how duplication was eliminated, and provide evidence of passing contract tests. Releases require maintainers to affirm constitutional compliance.

## Governance
- This constitution supersedes conflicting local guidelines for the Parrot repository; maintainers enforce compliance during reviews and releases.
- Amendments require a pull request referencing proposed changes, impact analysis, and updated checkpoints; at least two maintainers must approve before merge.
- Versioning follows semantic rules: MAJOR for principle removals or redefinitions, MINOR for new principles or sizable expansions, PATCH for clarifications. Update the Sync Impact Report and version line with every amendment.
- Compliance reviews occur at the start of Phase 0 planning, before merging any PR, and during release cut; defects trigger immediate remediation or a logged TODO with an assigned owner and deadline.

**Version**: 1.0.0 | **Ratified**: 2025-10-18 | **Last Amended**: 2025-10-18
