# Log 001: Legacy Build Script Audit

**Date**: 2026-01-03
**Source**: `Skalp_Legacy/_buildscript/BUILDSCRIPT.rb`
**Goal**: Deconstruct the monolithic script into atomic, reproducible Rake tasks.

## 1. The "Magic" Actions
We must replicate these *exactly* to achieve parity.

### A. Versioning & Configuration
*   **Legacy**: Reads/Updates `version.rb`, `constants.rb`.
*   **Parity Goal**: `rake version:bump[...]`
*   **Crucial Detail**: Handles "FastBuilds" (x.9999) differently from Releases.

### B. Encryption (The Black Box)
*   **Legacy**: 
    *   Uploads to Window/Mac encoder servers? (Need to verify if local or remote).
    *   Uses `RubyEncoder`.
    *   **Hardcoded Expiration**: WE MUST FIND THIS LINE.
*   **Parity Goal**: `rake build:encrypt` (Already partially exists in `secure_build.rake`).

### C. Server Interaction (The Gap)
*   **Legacy**: 
    *   `POST` to `new_skalp_version.php`?
    *   Updates `version.php` on server?
*   **Status**: COMPLETELY MISSING in `Skalp2026`.
*   **Action**: This is the highest risk area.

### D. Packaging
*   **Legacy**:
    *   Zips files.
    *   Renames to `.rbz`.
    *   Signs with SketchUp trust mechanism? (Need to verify).

## 2. Deep Trace Analysis

### A. Versioning Logic
*   **Source**: `BUILDSCRIPT.rb` (Line 46-69).
*   **Logic**: Scans `Dropbox/Skalp/Skalp BUILDS/` for `*.rbz` files to find `max_num`.
*   **Parity Requirement**: We must replicate this "Scan & Increment" logic or (better) replace it with a Git-Tag based source of truth, but *parity* implies scanning the folder for now.

### B. Encryption & Expiration
*   **Source**: `BUILDSCRIPT.rb` calls `encode` -> `buildscript_methods.rb` (Line 290) -> `./rb2rbe.sh`.
*   **Finding**: `grep` revealed `SKALP_EXPIRE=12/30/2099` in **5 separate shell scripts**.
*   **Resolution (2026-01-03)**: User manually updated `Skalp_loader.rb` to matched this (2099).
*   **Status**: **HANDLED** (Brute Force / Postponed to eternity). We will use `2099-12-31` as the constant.

### C. Server Interaction
*   **Source**: `BUILDSCRIPT.rb` (Lines 235-240).
*   **Method**: `Net::HTTP.get` to `http://license.skalp4sketchup.com/register_2_0/new_skalp_version.php`.
*   **Parameters**: `release_date`, `version` (int), `version_type`, `min_SU` (25), `max_SU` (25), `public`.
*   **Gap**: Skalp2026 has strictly *zero* code for this.

### D. Signing
*   **Source**: `buildscript_methods.rb` (Line 450).
*   **Method**: `sign_rbz`. Opens `safari` to the SketchUp signature portal.
*   **Manual Step**: Polls `~/Downloads` loop until file appears.
*   **Parity**: We can replicate this "Interactive Wait" easily in Rake.

### E. Legacy IDE Configurations (Reverse Engineered)
Based on user-provided screenshots and `ARGV` analysis, here is how the build was invoked:

| Configuration | Script Arguments | Effect |
| :--- | :--- | :--- |
| **BUILDSCRIPT fast** | `fastbuild` | `@fast_build=true`. Uses version `.9999`. Skips generic encryption/signing. |
| **BUILDSCRIPT fast debug** | `fastbuild debugger` | `@debugger=true`. Copies `Skalp_debugger_SkalpC.rb`. |
| **BUILDSCRIPT fast unencrypted** | `fastbuild local` | **Investigation Needed**: Argument `local` is passed but no obvious handler exists in `BUILDSCRIPT.rb`. Legacy no-op? |
| **BUILDSCRIPT internal fast windows** | `internal` | `@internal=true`. Triggers internal build logic (unsigned internal releases). |
| **BUILDSCRIPT release** | `release` | treated as default release (Argument falls through case statement to `%04d`). |
| **BUILDSCRIPT release alpha** | `alpha` | Sets `@version_type='alpha'`. |
| **BUILDSCRIPT release beta** | `beta` | Sets `@version_type='beta'`. |

**Insight**: The script relies entirely on positional `ARGV`. This is fragile.
**Recommendation**: The new Rake tasks should use named arguments (e.g., `rake build[type=alpha,debug=true]`) or distinct tasks (`rake build:fast`, `rake build:release`).

### F. Auxiliary Development Configurations (Batch 2 Findings)
The screenshots reveal 3 configurations that do **NOT** invoke `BUILDSCRIPT.rb`, but are critical dev tools:

| Configuration | Ruby Script | Purpose |
| :--- | :--- | :--- |
| **Skalp_hatchpatterns_DEVELOP** | `Skalp_hatchpatterns_DEVELOP.rb` | Likely generates/tests hatch pattern assets. |
| **Skalp_hatchpatterns_INSPECT** | `Skalp_hatchpatterns_INSPECT.rb` | likely inspects/validates hatch pattern files. |
| **Skalp_linestyles_DEVELOP** | `Skalp_linestyles_DEVELOP.rb` | Likely generates/tests linestyle assets. |

**Action**: These are "Sidecar Tools". We must add tasks to `task.md` to audit and migrate them (e.g., `rake dev:hatch:generate`).

### G. Remote Debugging (Critical Discovery)
The final screenshot (`SketchUp 2023 Debug`) reveals a **Remote Debugging** workflow using `rdebug-ide`.

| Setting | Value | Implication |
| :--- | :--- | :--- |
| **Gem** | `rdebug-ide` | We need this gem in our 2026 Gemfile. |
| **Ports** | `7354` (Debug), `26162` (Dispatcher) | We must ensure these ports are open/mapped. |
| **Mapping** | Local `.../Plugins` matches Remote | Parity requires we map our `src` to the SketchUp Plugins folder correctly. |

**Decision (2026-01-03)**: Remote Debugging is **NON-CRITICAL** for the initial migration. We will defer this setup.

### H. Native Compilation (The "Hard" Dependencies)
The legacy build included a complex C++ compilation step for:
1.  **Ruby C-Extension**: (`SkalpC.so` / `bundle`).
2.  **Standalone App**: `Skalp_external_application` (Links against full SketchUp/LayOut SDK).

**The Legacy Workflow**:
*   **macOS**: Automated via `xcodebuild` (CLI).
*   **Windows**: **Manual/VM Dependency**. The script paused and instructed the user to *"MAKE YOUR BUILD ON VISUAL STUDIO NOW!"* inside a Windows VM with specific (legacy) SDKs.
*   **Synchronization**: The Ruby script polled for the existence of the compiled `.dll` / `.exe` artifacts before proceeding.

**Modernization Directive**:
*   **Immediate**: We are actively porting this to **CMake** in Skalp2026 to remove the VS/VM dependency.
*   **Future**: Enable fully automated cross-platform CI/CD on GitHub Actions.

## 3. Comprehensive Audit Consensus
We have now fully deconstructed the Legacy Build System.

**What we have learned (The "Truth"):**
1.  **The "Build" is just a Script**: It's not a complex CI system. It's a Ruby script with positional arguments (`fast`, `release`, `alpha`, `beta`) that we can fully port to Rake.
2.  **"Magic" is Hardcoded**: Encryption expiry (`2099`), server URLs, and version logic are all static code we have located. There is no hidden cloud dependency other than the PHP endpoint.
3.  **Dev Tools are Separate**: Asset generation (`hatchpatterns`, `linestyles`) happens in "Sidecar Scripts", not the main build. We must migrate these separately.
4.  **Debugging was Robust**: The legacy setup supported full remote debugging. We cannot regress to "puts debugging".

**Next Immediate Step**:
With the **Build Script** and **Database** audited/secured, we must tackle the **Missing Link**:
*   **The Server Registration**.
*   We need to verify if we can replicate the `Net::HTTP.get` call to `new_skalp_version.php` without breaking the live server.
*   **Action**: Create `log_002_server_registration.md`.
