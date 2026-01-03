# 004. Security Parity Strategy

Date: 2026-01-02
Status: Accepted

## Context
The Skalp legacy codebase contains complex, multi-layered security and anti-tampering mechanisms (e.g., `Spoofing.rb`, `Security_check.rb`, `RubyEncoder` params, and hidden server checks).
Skalp2026 acts as a modernization platform, but breaking or weakening these security measures during the migration is an unacceptable risk.

## Decision
**We will strictly aim for 100% Functional & Security Parity first.**

1.  **No Refactoring of Security**: We will not attempt to "clean up" or "modernize" files like `Spoofing.rb` or the obfuscation pipeline during the initial build migration.
2.  **Clone the Build Process**: The new Rake tasks (`encrypt.rake`, `secure.rake`) must produce an artifact that is **identical in behavior** to the legacy build, including all side effects.
3.  **Defer Architectural Changes**: Any architectural improvements (e.g., moving to Observers) are blocked until we have a proven, automated build that matches the legacy release exactly.

## Consequences
*   **Positive**: Minimizes the risk of releasing a "cracked" or broken version of Skalp2026.
*   **Negative**: We carry forward "legacy debt" (e.g., monkey patching) into the new codebase initially.
*   **Mitigation**: We will mark these preserved components clearly but will not touch their logic until Phase 2 (Post-Parity).
