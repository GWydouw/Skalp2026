# 003. The Migration Manifest: Contract & Safety Protocol

**Type**: Process Contract / Manifest
**Status**: Active & Binding
**Date**: 2026-01-02

## 1. Preamble & Mandate
This document is the **Supreme Governing Contract** for the Skalp2026 migration.
It acknowledges that `Skalp_Legacy` is a complex, living system with hidden dependencies ("forgotten truths").
*   **Previous timelines (e.g., in `002`) are null and void.**
*   **Process over Speed**: We prioritize archaeological truth and production safety over development velocity.

## 2. Directives
### Directive A: Functional Parity (The "What")
We must reproduce **all** build variants, security layers, and side effects of `BUILDSCRIPT.rb` exactly.

### Directive B: Modern Quality (The "How")
While the *behavior* must be legacy-identical, the *implementation* must be modern and hardened.
*   **Test-First**: Write tests before implementation whenever possible.
*   **Coverage**: continuous use of **SimpleCov** to ensure we are guarded.
*   **Linting**: Strict automated linting (Rubocop) to catch errors early.
*   **Docs**: YARD documentation for all new code.

## 3. The Golden Rule: Legacy Audit First
**No code shall be written without a preceding audit.**

For every feature, Rake task, or logical block we attempt to migrate, we **MUST** cycle through this loop:
1.  **Legacy Audit**:
    *   Identify deeply: Locate the exact lines in `BUILDSCRIPT.rb` or associated scripts.
    *   Trace deeply: Follow every variable, file path, and server call to its root.
2.  **Analysis Document**:
    *   Write a finding doc. If unknown -> **HALT**.
3.  **Test Harness Specification (Test-First)**:
    *   Define the RSpec/Minitest spec.
    *   Set up SimpleCov limits.
4.  **Implementation**:
    *   Write the Rake task/code to satisfy the test.
    *   Write YARD docs.
5.  **Verification**:
    *   Run Linting & Tests.
    *   Verify output parity with legacy artifact.

## 4. Git Strategy
*   **Main Branch**: Reserved for production-ready, verified code.
*   **Migration Branch**: All work occurs in a dedicated branch (e.g., `migration/legacy-parity-v1`).
    *   **Commit Philosophy**: Commits should reflect *understanding*, not just *code*. A commit might be "Document findings on `Spoofing.rb`" rather than "Refactor `Spoofing.rb`".

## 5. CRITICAL: Live Production Safety Protocol
**⚠️ WARNING: WE HAVE ROOT/ADMIN ACCESS TO A LIVE SERVER (188.226.146.205).**

### 5.1. The "Red Line"
**Absolutely NO command** that touches the database (INSERT, UPDATE, DELETE, ALTER, DROP) or modifies server state may be executed until **Section 5.2** is verified.

### 5.2. Database Backup & Verification Strategy
Before we send *any* request that might write to the DB (even via PHP scripts):
1.  **Backup**: We must dump the entire MySQL schema and data.
    *   `mysqldump --all-databases --events --routines ...`
2.  **Verify**: We must prove the backup is valid.
    *   *Method*: Restore to a local isolated Docker container or separate test DB and verify row counts matches.
3.  **Rollback Plan**: Document the exact commands to restore the live server from the backup in < 5 minutes.

### 5.3. Safe Exploration
Usage of existing `GET` endpoints (read-only) is permitted for analysis *only if* we have confirmed they are side-effect free (idempotent). If in doubt, treat as dangerous.

## 6. Artifact Structure
To support this, we will introduce a granular tracking structure in `docs/architecture/migration_logs/`:
*   `log_001_version_calculation.md`
*   `log_002_encryption_parameters.md`
*   `log_003_server_handshake.md`
Each log captures the "Audit -> Plan -> Verify" cycle for that specific atomic unit.

## 7. The Horizon (Future Vision)
Our immediate goal is a functionally identical Skalp2026 release.
*   **Constraint**: We do not refactor the *logic* yet (e.g., how the server checks are done).
*   **Vision**: Once parity is reached, we intend to replace the entire build/server infrastructure with:
    *   Dockerized environments.
    *   Full GitHub CI/CD pipelines.
    *   Modernized server backend.
This "Horizon" vision justifies the rigorous QA investment now—we are building the safety net for that future refactoring.

## 8. Execution Authority
This manifest overrides any conflicting instruction in previous documents. When in doubt, **STOP**.
