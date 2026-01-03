# 004. Global Resource Inventory & Assessment

**Date**: 2026-01-02
**Status**: Basal Inventory
**Context**: This document maps the physical and digital geography of the Skalp project.

## 1. Code Repositories

### A. Skalp 2026 (The Future)
*   **Location**: `~/Dropbox/Sourcetree_repos/Skalp2026`
*   **Hosting**: GitHub (Private).
*   **Status**: Active, Clean, "Bleeding Edge" (Main branch).
*   **Key Characteristic**: The operational center for the Antigravity migration.

### B. Skalp_Legacy (The Past)
*   **Location**: `~/Dropbox/Sourcetree_repos/Skalp_Legacy`
*   **Hosting**: Bitbucket (Broken Remote).
*   **Origin**: Files synced from Dropbox (Guy's workspace).
*   **Status**: Frozen / Read-Only Reference.
*   **Risks**: Contains uncommitted local hacks, "forgotten truths".

### C. skalp-license-server (The Bridge)
*   **Location**: `server/skalp-license-server` (Legacy Path).
*   **Hosting**: Bitbucket (Legacy).
*   **Status**: Polluted. Contains massive `.rbz` binaries in git history.
*   **Action Required**:
    1.  Clean history (remove large blobs).
    2.  Migrate to GitHub.
    3.  Re-integrate as Git Submodule in Skalp2026 (ignoring large binaries).

## 2. Live Infrastructure (The "Server")

### Host Identification **(CRITICAL UPDATE)**
*   **Host**: `license.skalp4sketchup.com`
*   **Verified IP**: `198.211.120.37` (DigitalOcean).
    *   *Note*: Previous docs cited `188.226.146.205`. This is a major update. The 198 IP is the current truth.
*   **OS**: Ubuntu 18.04.6 LTS (Bionic Beaver).

### Services
1.  **MySQL Database**: Stores licenses, users, resellers.
    *   *Creds*: `root` / `skalp14` (Local access only).
2.  **PHP Backend**: `new_skalp_version.php`, Reseller Portal.
3.  **Artifact Hosting**: Serves `.rbz` updates to clients.

## 3. The "Archived" Local Data
**Location**: `~/Dropbox/Skalp`
**Role**: Archaeology Site (Read-Only).

### Key Contents (Content Table)
A selected summary of the ~174 items found:
*   **Business & Sales**:
    *   `All Fasspring Orders/`, `FastSpring/` (Sales logic/history).
    *   `Boekhouding/`, `Opbrengst Skalp 2.0.numbers`.
    *   `Resellers/`, `SIGNED RESELLER AGREEMENTS/`.
*   **Development & Build History**:
    *   `Skalp BUILDS/` (Historic artifacts).
    *   `RUBYENCODER INSTALLERS/`, `Ruby Encoder/` (Obfuscation tools).
    *   `Skalp Server Database Backups/` (Ancient: Oct 2014, ~2.8MB).
    *   `Skalp SQL database backup/` (Historic: Feb 2019, ~300MB).
    *   **CRITICAL DISCOVERY**: `.../Skalp/skalp-license-server/Sandbox/Backups database/`
        *   Contains **FRESH BACKUPS**: `skalp_2025-12-18.sql`, `skalp_2026-01-03.sql` (Today!).
        *   Size: ~800MB.
    *   `Skalp Crack/` (Analysis of vulnerabilities?).
*   **Design & Marketing**:
    *   `Skalp tutorials/`, `Skalp movies/`, `Skalp demo's/`.
    *   `3D Basecamp .../` (Presentations).
    *   `Skalp Manual/` (Old manual source).

### 4. Strategic References (Modernization)
*   **SketchUp Extension Architecture (SEA)**:
    *   **Location**: `/Users/jeroentheuns/RubymineProjects/SketchUp Sandbox` (Local) / GitHub (Remote).
    *   **Role**: The "Template/Reference" for modern tooling.
    *   **Status**: `Skalp2026` Rake tasks were ported from here. Future goal is to merge generic logic back to SEA.
*   **Docs**:
    *   `Manual/`, `EULA.pages`, `FAQ.pages`.

## 5. Documentation & Media
*   **Legacy Manual**: [manula.com/manuals/skalp](https://www.manula.com/manuals/skalp) (Reference for intended logic).
*   **Video Tutorials**: [YouTube Playlist](https://www.youtube.com/playlist?list=PL4o5Ke8mDBjjka1kZPJ5-tMhf_d51CVbr).
*   **Marketing/Sales**: [skalp4sketchup.com](http://www.skalp4sketchup.com) (Frontend, FastSpring integration).

## 5. Strategic Directives from Inventory
1.  **IP Correction**: Update all server-access scripts to target `198.211.120.37`.
2.  **Backup Priority**: The `Skalp Server Database Backups/` folder in the local archive suggests a precedent for backups. We must inspect these to understand *how* they were done (dump format).
3.  **Reseller Logic**: The `Resellers` folder likely contains the logic or contracts that match the PHP portal code.
