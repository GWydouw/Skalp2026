# Log 004: Encryption Workflow & File Grouping

**Date**: 2026-01-03
**Status**: Analyzed / Ready for Parity Implementation
**Component**: Build System / Rake

## 1. The Hybrid Encryption Model
**Finding**: The legacy build does NOT use a local `rubyencoder` binary.
**Mechanism**:
1.  **Prep**: Files are collected into a local folder (`encoder_to`).
2.  **Upload**: Files are `scp`'d to `skalpadmin@builder.skalp4sketchup.com`.
3.  **Execute**: An `ssh` command runs a specific shell script on the server (e.g., `rb2rbe.sh`).
4.  **Download**: The resulting `.rbe` (or `.rb`) files are `scp`'d back to `encoder_from`.
5.  **Compile**: Most encryption results are then read, Base64 encoded, and written as C++ `.data` files to be compiled into `SkalpC.so`.

## 2. The 6 Encryption Groups
We must verify parity by correctly routing every file to its designated legacy group.

### Group 1: The Main Cluster (`encode` -> `rb2rbe.sh`)
**Logic**: Standard encryption.
**Files**: `Skalp_start.rb`, `Skalp_model.rb`, `Skalp_section.rb`, `Skalp_materials.rb`, and ~20 others.
**Crucial Addition**: `Skalp_dialog.rb` (See Group 6).
*Catch-all*: Any new file in Skalp2026 likely belongs here unless it accesses licensing APIs.

### Group 2: No-Lic Rails (`encode_no_lic_rails` -> `rb2rbe_no_lic_rails.sh`)
**Logic**: Encryption without license checks?
**Files**:
*   `Skalp_license.rb`
*   `macaddr.rb`

### Group 3: No-Lic (`encode_no_lic` -> `rb2rbe_no_lic.sh`)
**Logic**: Encryption without license checks.
**Files**:
*   `Skalp_loader.rb`
*   `Skalp_UI.rb` (and ~10 others like `Skalp_info.rb`, `Skalp_paintbucket.rb`)

### Group 4: RBS (`encode_rbs` -> `Scrambler`)
**Logic**: Uses SketchUp Scrambler?
**Files**: (Empty in legacy script logic, but defined).

### Group 5: The Special Cases
**Logic**: Single-file error catching wrappers.
*   `Skalp_lic.rb` -> `rb2rbe_skalp_lic_error_catching.sh`
*   `Skalp_version.rb` -> `rb2rbe_skalp_version_error_catching.sh`

### Group 6: The Concatenation (`Skalp_dialog.rb`)
**Logic**: Multiple files are concatenated into one *before* encryption.
**Source Files**:
*   `Skalp_style_settings.rb`
*   `Skalp_webdialog.rb`
*   `Skalp_section_dialog.rb`
*   ... (9 files total)
**Output**: `Skalp_dialog.rb` -> Added to **Group 1**.

## 3. Implementation Directive
*   **Task**: `rake build:encrypt`
*   **Requirements**:
    *   Must verify SSH access to `builder.skalp4sketchup.com` (user has keys?).
    *   Must implement `concatenate` logic for Group 6.
    *   Must iterate through Groups 1-3+5 and execute the remote flow.
*   **Fallback**: For local dev (without server access), we need a `mock` mode that just copies files (unencrypted) or we fail. The user said: "We cannot bypass ... needs assesment".
