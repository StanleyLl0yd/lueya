# Repository Instructions

## General

- Preserve the native macOS architecture.
- Prefer SwiftUI and AppKit.
- Avoid Electron, Tauri, and Qt.
- Keep dependencies minimal and justified.
- Avoid unnecessary abstraction or code churn.
- Write code and code comments in English.
- Keep UI terminology consistent.

## Security

- Never commit tokens, passwords, or cookies.
- Use Keychain for credentials.
- Never bypass DRM or access controls.
- Do not bundle copyrighted provider content.
- Do not claim official provider affiliation.
- Review third-party licenses before adoption.
- Preserve least-privilege access.

## Implementation

- Validate external integrations before
  building permanent abstractions around them.
- Include tests for relevant behavior.
- Prefer incremental, reviewable changes.
- Document significant architectural decisions.
- Do not introduce placeholder passing CI checks.

## Audit requirements

At the end of EVERY milestone, perform a full
repository-wide audit, security review,
code review, and refactoring assessment.

This includes all source code, scripts,
tests, configurations, workflows, dependencies,
documentation, and build/release infrastructure.

A diff-only review is not sufficient.

Track findings, applied fixes, test results,
and any remaining blockers.

Do not mark a milestone accepted while
required verification is incomplete.
