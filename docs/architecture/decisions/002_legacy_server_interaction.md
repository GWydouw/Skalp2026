# 002. Legacy Server Interaction

Date: 2026-01-02
Status: Accepted

## Context
The legacy build process (`BUILDSCRIPT.rb`) interacts with the "Live Server" (`license.skalp4sketchup.com`) to register new versions. Additionally, the `skalp-license-server` repository contains a `config/version.php` file that appears to be manually updated. We need to determine how Skalp2026 will handle these interactions to ensure:
1.  Registration of new versions in the database.
2.  Notification of updates to existing users (both Legacy and modern).

## Findings

### 1. `new_skalp_version.php` (The API)
*   **Path**: `/register_2_0/new_skalp_version.php`
*   **Action**: Inserts a row into the `skalp_versions` database table.
*   **Parameters**: `release_date`, `version`, `version_type`, `min_SU_version`, `max_SU_version`, `public`.
*   **Critical Detail**: The `version` parameter expects an **Integer** representation (e.g., `2025.0.123` -> `20250123`).
*   **Security Warning**: The legacy system has multi-layered security checks. Any deviation in these parameters (or side effects of this call) could trigger anti-piracy countermeasures in the client. Parity is paramount.
*   **Usage**: Used by `BUILDSCRIPT.rb` to "officially" register a build.

### 2. `config/version.php` (The Static Config)
*   **Path**: `www/html/config/version.php`
*   **Content**: PHP variables `$currentVersion`, `$betaVersion`, `$alphaVersion`.
*   **Usage**: Consumed by `versioncheck/index.php` and `versioncheck_3_0/index.php`.
*   **Implication**: This file drives the update checks for **legacy clients** (and potentially current ones). If this is not updated, users will not see the new version pop up.
*   **Current Process**: Manually updated via text editor and synced/deployed.

## Decision

### 1. Automate API Registration
We will implement a Rake task `deploy:register` that sends the HTTP GET request to `new_skalp_version.php`.
*   **Requirement**: It must correctly format the version as an integer (`YYYYMM...`).
*   **Requirement**: It must accept parameters for `public` (stable vs beta).

### 2. Automate `version.php` Updates
Because `version.php` controls the update notification for the entire install base, we cannot leave it to manual edits (risk of human error/forgetting).
*   **Strategy**: Since `skalp-license-server` is currently an external folder/repo, we will need a strategy to update it.
    *   **Short Term**: The `deploy:register` task should failing/warn if it cannot verifying the server version matches.
    *   **Long Term**: We should integrate `skalp-license-server` so the build script can modify `version.php` locally and deploy it (via Git push or SSH SCP).

### 3. SSH Access Prerequisite
To robustly handle #2 and to run `RubyEncoder` (ADR 001), we **must** restore and verify SSH access to the live server `license.skalp4sketchup.com` (`188.226.146.205`).

## Consequences

*   **Positive**: Eliminates the "magic" HTTP call in the legacy script.
*   **Positive**: ensures the database is always in sync with the released build.
*   **Negative**: Updating `version.php` remains a "last mile" problem until we fully integrate the license server repo (ADR Pending).
*   **Risk**: If we register in DB but forget `version.php`, users won't know the update exists.
