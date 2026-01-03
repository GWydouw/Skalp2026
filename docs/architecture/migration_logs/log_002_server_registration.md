# Log 002: Server Registration Audit

**Date**: 2026-01-03
**Component**: `new_skalp_version.php` interaction.
**Goal**: Verify parity between Legacy `BUILDSCRIPT.rb` and Skalp2026 `tasks/version.rake`.

## 1. The Comparison
We compared the `Net::HTTP.get` calls in both scripts.

### Legacy (`BUILDSCRIPT.rb` Line 236)
```ruby
uri = URI("http://license.skalp4sketchup.com/register_2_0/new_skalp_version.php?release_date=#{release_date}&version=#{version}&version_type=#{version_type}&min_SU_version=#{su_min}&max_SU_version=#{su_max})&public=#{public}")
```
**CRITICAL OBSERVATION**: Note the `)` character after `#{su_max}`.
*   Sent URL: `...&max_SU_version=25)&public=0`
*   This looks like a **Typo** in the legacy script that has been running for years.

### Modern (`tasks/version.rake` Line 40)
```ruby
uri = URI("http://license.skalp4sketchup.com/register_2_0/new_skalp_version.php?release_date=#{release_date}&version=#{version_number}&version_type=#{version_type}&min_SU_version=#{su_min}&max_SU_version=#{su_max}&public=#{public_flag}")
```
*   Sent URL: `...&max_SU_version=25&public=0`
*   **Parity Gap**: The modern script *fixed* the typo.

## 2. Risk Analysis
*   **Scenario A (Benign)**: The PHP server ignores the extra `)`. In this case, the modern script is fine.
*   **Scenario B (Strict)**: The PHP server *expects* the `)` (unlikely) or parses `max_SU_version` as `25)` string.
    *   If PHP does `$max = $_GET['max_SU_version']`, it might be saving `25)` into the DB.
    *   If the modern script sends `25`, we might break data consistency.

## 3. The Test Plan (Manifest Step 3)
We must determine if the "Fix" is safe.

1.  **Dry Run**: We cannot just run it against the live server without knowing.
2.  **Inspection**: Ideally, we would look at the PHP code `new_skalp_version.php`. (Do we have it in the checked-out legacy repo? `Skalp_Legacy` likely only has the client code).
3.  **Alternative**: Check the database content.
    *   We have `skalp_2026-01-03.sql`.
    *   We can check the `skalp_versions` table to see what values are stored in `max_SU_version`.
    *   If they are pure integers (`25`), the typo was harmless/ignored.
    *   If they are strings (`25)`), we must reproduce the typo.

## 4. Immediate Action
1.  **Check Local Backup SQL**: Search for `skalp_versions` inserts in `skalp_2026-01-03.sql` (head/grep).
2.  **Result (2026-01-03)**:
    *   Found INSERT statements (e.g., `(297,...,25,25,0,NULL)`).
    *   Values for `max_SU_version` are **CLEAN INTEGERS** (`25`), not strings like `'25)'`.

## 5. Conclusion
*   **Sanitization Confirmed**: The PHP backend or MySQL driver strips the trailing `)` from the legacy request.
*   **Parity Verdict**: We **DO NOT** need to replicate the typo. The "Clean" implementation in `tasks/version.rake` is **SAFE** and **CORRECT**.
*   **Action**: `tasks/version.rake` is approved for use.
