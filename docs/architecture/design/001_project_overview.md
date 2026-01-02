# 001. Project Overview & Strategy

**Type**: Living Design Document
**Status**: Active
**Last Updated**: 2026-01-02

## 1. Executive Summary: The Skalp Migration

We are transitioning the foundational architecture of Skalp from its legacy codebase (**Skalp_Legacy**) to a modern, modular architecture (**Skalp2026**). This process involves a "Double Analysis": deep archeology of the legacy system to identify implicit business logic, coupled with a critical assessment of the new architecture's readiness.

## 2. Repositories & Context

The migration spans three primary components:

| Component | Path | Role | Status |
| :--- | :--- | :--- | :--- |
| **Skalp_Legacy** | `.../Skalp_Legacy` | The running, proven codebase (v2025). Contains all business logic, build scripts, and server interactions. | **Reference / Frozen** |
| **Skalp2026** | `.../Skalp2026` | The new codebase. Modular, using `Rake` and `CMake`. Incorporates "SketchUp Extension Architecture" (SEA) patterns. | **Active Development** |
| **License Server** | `.../skalp-license-server` | PHP-based backend for licensing and version checks. Host: `license.skalp4sketchup.com` (`188.226.146.205`). | **To Be Integrated** |

## 3. Documentation Structure

We follow the "Design vs. Decisions" standard:

*   **`docs/architecture/design/`**: Living documents describing the *current* state of the system.
    *   *Example*: This document, API specs, Module diagrams.
*   **`docs/architecture/decisions/`**: Immutable records (ADRs) of *why* choices were made.
    *   *Example*: "Why we chose CMake", "Analysis of Legacy Build System".

## 4. The "Double Analysis" Strategy

We strictly separate **Analysis** from **Execution**. No builds or deployments are performed during this phase.

### Phase 1: Legacy Archeology
*   **Goal**: Make implicit knowledge explicit.
*   **Outcome**: Recorded in `docs/architecture/decisions/`.

### Phase 2: Skalp2026 Assessment
*   **Goal**: Evaluate structural decisions.
*   **Outcome**: Gap analysis recorded in future ADRs.

## 5. Risk Register (Living)

*   **⚠️ Live Server Access**: We lack automated access to the live server.
*   **⚠️ "Time Bomb" Logic**: Legacy code has hardcoded expiration dates.
*   **⚠️ Dropbox Dependency**: Legacy builds rely on local Dropbox paths.
