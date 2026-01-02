# Skalp 2025 Hotfix Report (Post-Mortem & Technical Reference)

**Date:** January 2, 2026 (Reflecting work done Dec 31, 2025)
**Context:** Emergency Hotfix for Skalp Legacy Versions (2021-2025)

## 1. The Incident
**Symptom:** Skalp versions failed to start on/after Jan 1, 2025.
**Root Cause:** Hardcoded date check in the encrypted `Skalp.rbe` core (and legacy loaders) preventing execution past the expiration date.
**Impact:** Global outage for all existing Skalp users.

## 2. The Solution Strategy
We deployed a two-pronged solution:
1.  **Full Installer Patching (Primary):** Re-releasing installers for all supported SketchUp versions (2021-2025) with the fix pre-injected.
2.  **Standalone Hotfix (Secondary):** A small extension (`Skalp_Hotfix.rbz`) for users who cannot reinstall.

### Technical Implementation

#### The "Monkey Patch" (`skalp_hotfix.rb`)
We created a Ruby script that intercepts `Time.new` *strictly* during the loading of the Skalp extension.
- **Mechanism:** It creates a wrapper around `Time.new` that returns a fake date (2024) if called without arguments, effectively bypassing the expiration check.
- **Scope:** It uses `alias_method` to swap `Time.new` only for the duration of the Skalp load, instantly restoring the original `Time.new` afterwards to prevent side effects on other plugins.
- **Namespace:** encapsulated in `module Skalp::Hotfix`.

#### Injection Strategy
To patch the standard installers without decrypting/recompiling the core source code (which was unavailable or risky to modify):
1.  We extracted the installer `.rbz`.
2.  We located `install_Skalp.rb` (the main loader).
3.  We **PREPENDED** a `require` statement to load our `skalp_hotfix.rb` *before* the encrypted payload loads.
    ```ruby
    # Injected by Skalp Hotfix Patcher
    require File.join(File.dirname(__FILE__), 'skalp_hotfix.rb')
    # ... original code ...
    ```
4.  We bundled `skalp_hotfix.rb` into the installer package.

## 3. Signing Challenges & "No Encryption"
During the repackaging process, we encountered a critical blocking issue with the SketchUp signing portal:
- **Issue:** The signing portal automatically encrypted our patch files into `.rbe`, which broke the `require` paths and seemingly the monkey-patching timing.
- **Workaround:** We modified our automated signing tool (`sea_toolkit/tools/sign/sign.ts`) to support a `--no-encryption` flag.
- **Verification:** We manually verified (via an interactive pause in the script) that the "No Encryption" checkbox was selected during the signing process.

## 4. Artifacts & Locations
All patched and signed installers were verified on Dec 31, 2025.

**Location:** `/Users/jeroentheuns/Library/CloudStorage/Dropbox/Skalp/Skalp BUILDS`
**Files:**
- `Skalp_2025_0_0006_hotfix.rbz`
- `Skalp_2024_0_0011_hotfix.rbz`
- `Skalp_2023_0_0004_hotfix.rbz`
- `Skalp_2022_0_0013_hotfix.rbz`
- `Skalp_2021_0_0011_hotfix.rbz`
- `Skalp_Hotfix_SIGNED.rbz` (Standalone Extension)

**Live Distribution:**
These files were uploaded to `http://download.skalp4sketchup.com/downloads/latest/`.

## 5. Antigravity Workspace Changes (SEA)
To support this effort, the following changes were made to the `SketchUp Sandbox` workspace:
1.  **signing tool (`sign.ts`):** Modified to support `--no-encryption` and `--headless=false` (interactive mode).
2.  **Documentation:** This report.


## 6. Handover Instructions
To transfer this solution to the `Skalp_Legacy` workspace or repository:
1.  Copy the `skalp_hotfix.rb` source code.
2.  Copy the `universal_install_skalp.rb` (the patcher script used to batch process archives).
3.  Copy this report.
4.  Store them in a `maintenance/2025_hotfix` folder in the legacy repo.

## 7. Reconstruction Guide
**How to rebuild the "Patched Installer" for any version:**

If you need to apply this fix to another legacy installer in the future:

1.  **Prepare Files:** Have `skalp_hotfix.rb` and `universal_install_skalp.rb` ready.
2.  **Unpack Original:** Rename the original installer `.rbz` (e.g., `Skalp_2021...rbz`) to `.zip` and unzip it.
3.  **Inject Payload:**
    *   Copy `skalp_hotfix.rb` into the root of the unzipped folder.
4.  **Swap Installer Logic:**
    *   Identify the original installer script (usually `Skalp_Skalp_installer.rb` or similar).
    *   Replace its content with the content of `universal_install_skalp.rb`.
    *   *Critical:* Ensure the filename matches what SketchUp expects to load (i.e., keep the original filename, just replace the code).
5.  **Repackage:** Zip the folder contents back into a `.zip` and rename to `.rbz`.
6.  **Sign:** Process with the signing tool using `--no-encryption`.
