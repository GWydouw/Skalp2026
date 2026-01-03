# 002. Implementation Plan: Skalp2026 Build & Deployment

**Status**: Planning
**Date**: 2026-01-02

## 1. Goal
**Primary Objective**: Reach **100% Parity** with the Legacy Build & Deployment system (`BUILDSCRIPT.rb`).
*   We must reproduce **all** build variants (Release, Fastbuild, Debug).
*   We must reproduce **all** security layers, obfuscation steps, and server interactions exactly as they were.
*   **Constraint**: Do NOT refactor or "improve" security logic until parity is achieved and verified.

## 2. Security Warning (Crucial)
**⚠️ Do NOT share passwords or private keys.**
*   I cannot see your Keychain or Cyberduck passwords.
*   When we set up IDE configs (VS Code/RubyMine), we will use **Environment Variables** (e.g., `SKALP_DEPLOY_KEY`) or local files that are **ignored by Git** (e.g., `.env`, `sftp-config.json`).
*   **Never commit secrets to the repository.**

## 3. Phase 1: License Server Migration
**Goal**: Move `skalp-license-server` from Bitbucket to GitHub and clean it up.

1.  **Create GitHub Repo**: Create `skalp-license-server` on your GitHub account (private).
2.  **Migrate Code**:
    *   Clone the Bitbucket repo.
    *   (Optional but Recommended) Prune large `.rbz` files from history using `git-filter-repo` if you want a clean start.
    *   Push to the new GitHub remote.
3.  **Integrate**:
    *   Add as submodule: `git submodule add [github-url] server/skalp-license-server`.
    *   Configure `server/skalp-license-server` to ignore `www/html/downloads/*.rbz` (to prevent future bloat).

## 4. Phase 2: Server Interaction Tasks
**Goal**: Replace manual `BUILDSCRIPT.rb` logic with Rake tasks.

### 4.1. SSH Access
We need to verify SSH access to `license.skalp4sketchup.com` (IP: `198.211.120.37`).
*   **Action**: You need to add your public SSH key (and the CI/CD key later) to `~/.ssh/authorized_keys` on the server.
*   **Task**: Implement `rake server:check_connection` to verify access.

### 4.2. Registration Task (`deploy:register`)
Implement a Rake task that:
1.  Calculates the integer version (e.g., `20260105`).
2.  Sends the HTTP GET request to `new_skalp_version.php` with the correct parameters.

### 4.3. Version Config Update
Implement `rake deploy:server` which:
1.  Updates `server/skalp-license-server/www/html/config/version.php` with the new version numbers.
2.  Commits and pushes the submodule.
3.  (Optional) Triggers a `git pull` on the live server via SSH.

## 5. Phase 3: IDE & Developer Experience
**Goal**: standardized "One Click" setup.

Since we couldn't find `deployment.xml` in the repo (good, it shouldn't be valid in git anyway):

1.  **VS Code Setup**:
    *   Create `.vscode/tasks.json` to run the Rake tasks.
    *   (Optional) Use `sftp` extension for browsing the server, configured via a gitignored config file.
2.  **RubyMine Setup**:
    *   We will document how to recreate the deployment config manually, pointing to the `server/skalp-license-server` path locally.

## 6. Execution Sequence
1.  **Setup**: Migrate Repo to GitHub & Add Submodule.
2.  **Code**: Write `tasks/deploy.rake` (Register & Server Update).
3.  **Verify**: Test `rake deploy:register` against the live DB (carefully, maybe with a dummy version first).
4.  **Finalize**: Update documentation with the new workflows.
