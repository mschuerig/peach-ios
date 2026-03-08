# Peach — arc42 Architecture Documentation

**Version:** 1.1
**Date:** 2026-03-08
**Based on:** arc42 Template v9.0

This documentation describes the software architecture of **Peach**, an iOS pitch ear training app. It follows the [arc42](https://arc42.org) template structure.

## Table of Contents

| # | Section | Description |
|---|---|---|
| 1 | [Introduction and Goals](01-introduction-and-goals.md) | Requirements overview, quality goals, stakeholders |
| 2 | [Architecture Constraints](02-constraints.md) | Technical, organizational, and convention constraints |
| 3 | [Context and Scope](03-context-and-scope.md) | System boundary, business and technical context |
| 4 | [Solution Strategy](04-solution-strategy.md) | Technology decisions, decomposition, quality strategies |
| 5 | [Building Block View](05-building-block-view.md) | Static decomposition: Level 1 (features + core) and Level 2 (core internals) |
| 6 | [Runtime View](06-runtime-view.md) | Pitch comparison loop, pitch matching loop, startup, interruption handling |
| 7 | [Deployment View](07-deployment-view.md) | iOS app sandbox, storage, distribution |
| 8 | [Cross-cutting Concepts](08-crosscutting-concepts.md) | Two-world architecture, observer pattern, DI, settings propagation, error handling |
| 9 | [Architecture Decisions](09-architecture-decisions.md) | Key ADRs: SwiftData, SoundFont, Kazez algorithm, PlaybackHandle, and more |
| 10 | [Quality Requirements](10-quality-requirements.md) | Quality scenarios for performance, reliability, usability, testability |
| 11 | [Risks and Technical Debt](11-risks-and-technical-debt.md) | Known risks and deferred work items |
| 12 | [Glossary](12-glossary.md) | Key architectural terms (references full glossary) |

## Related Documents

- [Product Requirements Document](../planning-artifacts/prd.md)
- [Architecture Decision Document](../planning-artifacts/architecture.md)
- [UX Design Specification](../planning-artifacts/ux-design-specification.md)
- [Glossary](../planning-artifacts/glossary.md)
- [Epics and Stories](../planning-artifacts/epics.md)
