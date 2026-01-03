# Log 005: File Mapping & Delta Analysis

**Date**: 2026-01-03
**Status**: Pending User Review
**Component**: Encryption Groups

## 1. Analysis Approach
Compared `SOURCE/Skalp_Skalp2026/**/*.rb` against `BUILDSCRIPT.rb`'s `collect_files` method.

## 2. Findings
**Total Files in New Repo**: 100+ Ruby files.
**Legacy Files**: Most core files (`Skalp.rb`, `Skalp_model.rb`) exist and map to Group 1.

### A. New "Feature" Files (Proposed: Group 1 - Main Encrypted)
These appear to be core logic additions by Guy.
*   `Skalp_box_section.rb`
*   `Skalp_box_section_tool.rb`
*   `Skalp_box_temp.rb`
*   `Skalp_rear_view_manager.rb`
*   `Skalp_rear_view_state.rb`
*   `Skalp_diagnostics.rb`
*   `Skalp_migration.rb`
*   `Skalp_progress_dialog.rb`
*   `Skalp_logger.rb`
*   `Skalp_html_inputbox.rb`
*   `Skalp_material_replacement.rb`
*   `Skalp_material_dialog_helpers.rb`

### B. New Libraries (Proposed: Group 3 - No Lic / Copy Raw?)
**CRITICAL**: These are directories containing 50+ files. Legacy script did NOT handle deep directories recursively for encryption.
1.  **`chunky_png/`** (Full Gem)
2.  **`shellwords/`** (Stdlib overrides?)
*   **Risk**: If we pass these to `rubyencoder`, it might break them or be incredibly slow.
*   **Recommendation**:
    *   **Option A**: Encrypt them (Group 3).
    *   **Option B**: Copy them RAW (Unencrypted). *Likely safer for libraries.*

### C. The "Skalp_cca_functions"
Legacy handled this via `convert` loop. In Skalp2026, it is a directory.
*   `Skalp_cca_functions/*.rb` (19 files).
*   **Action**: Map to **Group 1** (or special CCA handling if legacy did that).

## 3. The Concatenation Group (Group 6)
The following files exist in `Source` and MUST be concatenated into `Skalp_dialog.rb`:
*   `Skalp_style_settings.rb`
*   `Skalp_webdialog.rb`
*   `Skalp_section_dialog.rb`
*   `Skalp_hatch_dialog.rb`
*   `Skalp_tile_size.rb`
*   `Skalp_style_rules.rb`
*   `Skalp_rendering_options.rb`
*   `Skalp_export_import_materials.rb`
*   `Skalp_scenes2images.rb`

## 4. Proposed Mapping Table for Implementation

| File/Pattern | Legacy Group | Proposed Actions |
| :--- | :--- | :--- |
| `Skalp_model.rb`, etc. | Group 1 | Encrypt Main |
| `Skalp_box_*.rb` | **NEW** | **Encrypt Main (Group 1)** |
| `Skalp_rear_view_*.rb` | **NEW** | **Encrypt Main (Group 1)** |
| `chunky_png/**/*.rb` | **NEW** | **Ask User** (Encrypt vs Copy) |
| `shellwords/**/*.rb` | **NEW** | **Ask User** (Encrypt vs Copy) |
| `Skalp_license.rb` | Group 2 | Encrypt No-Lic-Rails |
| `Skalp_loader.rb` | Group 3 | Encrypt No-Lic |
