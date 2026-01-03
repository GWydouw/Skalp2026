# 001. Legacy Build & Deployment Analysis

Date: 2026-01-02
Status: Accepted

## Context
We are migrating from `Skalp_Legacy` (Ruby script based) to `Skalp2026` (Rake/CMake based). We need to understand the implicit logic in the legacy system (`BUILDSCRIPT.rb`) to ensure no critical business logic is lost during the transition.

## Findings (Legacy Analysis)

### 1. Versioning & "Fastbuilds"
*   **Legacy**: Scanned Dropbox filenames to determine the next version.
*   **Fastbuilds**: Version `*.9999` triggered debug logic in both code and server.
*   **Gap**: Skalp2026 currently lacks a rigorous versioning source of truth.

### 2. Encryption Loop
*   **Legacy**: Local copy loop with `RubyEncoder`.
*   **Skalp2026**: Uses `encrypt.rake` for remote SSH encryption.
*   **Decision**: The SSH approach in Skalp2026 is superior but needs parameterized expiration dates.

### 3. Live Server Registration
*   **Legacy**: `BUILDSCRIPT.rb` sent an HTTP GET to `license.skalp4sketchup.com/register_2_0/new_skalp_version.php`.
*   **Skalp2026**: **Missing**.
*   **Impact**: Without this, the extension cannot notify users of updates.

## Decision
1.  **Adopt Skalp2026 Rake System**: We will officially move to the modular `tasks/*.rake` architecture.
2.  **Implement `deploy:register`**: We must recreate the "Live Server Registration" as a Rake task.
3.  **Modernize Versioning**: We will move away from Dropbox scanning to a git-tag or file-based versioning source.
4.  **Parameterize Encryption**: We will modify `encrypt.rake` to accept dynamic expiration dates, removing the manual "Time Bomb" edits.

## Consequences
*   **Positive**: Decoupling from user-specific Dropbox paths.
*   **Positive**: "Infrastructure as Code" via Rake tasks.
*   **Negative**: Requires immediate work to restore Live Server access (SSH) and build the registration task.
*   **Risk**: If we miss any other implicit legacy logic, `Skalp2026` releases might fail silently in edge cases (e.g., updates not triggering).
