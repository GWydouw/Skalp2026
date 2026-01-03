# 003. License Server Integration

Date: 2026-01-02
Status: Accepted

## Context
The `skalp-license-server` is a critical component that handles:
1.  **Licensing**: Activation and validation.
2.  **Updates**: Hosting the `version.php` config and the `.rbz` binaries.
3.  **Deployment**: Currently manually copied/managed.

It is currently located in a separate legacy path (`.../Skalp (1)/skalp-license-server`) and points to `bitbucket.org/Skalp/skalp-license-server.git`.

## Findings

### 1. Repository State
*   **Remote**: `ssh://git@bitbucket.org/Skalp/skalp-license-server.git`.
*   **Content**: Contains PHP code (`www/html`) but also **large binary artifacts** (`www/html/downloads/release/*.rbz`).
    *   *Issue*: Storing binaries in Git is a bad practice and bloats the repo, making it slow to clone.
*   **Structure**: It's a full webroot dump.

### 2. Integration Needs
To automate `deploy:server` (ADR 002), Skalp2026 needs programmatic access to this codebase to:
*   Update `config/version.php`.
*   Commit and push changes.
*   Deploy to the live server.

## Decision

### 1. Add as Git Submodule
We will add `skalp-license-server` as a **Git Submodule** to the Skalp2026 repository at `server/skalp-license-server`.
*   *Why*: Keeps the history of the server code separate but links it to the specific version of the extension. allows us to run server-side scripts from Rake.

### 2. Future: Decouple Binaries
We must stop committing `.rbz` files to this git repository.
*   *Plan*: The `deploy` task should upload `.rbz` files directly to the server (via SCP) to a downloads folder, rather than committing them to git.
*   *Cleanup*: Review if we can purge history or start a fresh "code-only" server branch, but for now, we deal with the legacy bloat.

### 3. Deployment Workflow
The new workflow will be:
1.  `rake build`: Creates package.
2.  `rake deploy`:
    *   SCP package to `builder.skalp4sketchup.com:/var/www/html/downloads/...`.
    *   Update `server/skalp-license-server/www/html/config/version.php` locally.
    *   Commit and Push server repo.
    *   SSH to server and `git pull` (or symlink switch).

## Consequences
*   **Positive**: "One command" deployment.
*   **Positive**: Version config is version-controlled alongside the build.
*   **Negative**: The `git submodule` will be heavy due to past binaries.
*   **Action**: Need to run `git submodule add` and potentially configure sparse-checkout if it's too huge.
