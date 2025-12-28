# Testing Strategy

This project employs a multi-layered testing strategy to ensure stability for both the core geometry logic and the SketchUp extension integration.

> [!TIP]
> **New to the project?** Run `rake doctor` first to verify your development environment is correctly set up before running tests.

## Quick Reference

| Command | What It Does |
|---------|--------------|
| `rake doctor` | Verify development environment |
| `rake test` | Run unit tests (headless, mocked SketchUp API) |
| `rake test:meta` | Run meta-tests (build integrity, tooling verification) |
| `rake test:all` | Run all tests (unit + meta) |
| `rake lint` | Run RuboCop linting |

---

## 1. Unit Tests (Minitest)

Located in `tests/unit/`.

These tests run in a standalone Ruby environment (CLI) and **mock** the SketchUp API. They are fast and robust for testing pure logic.

### How to Run
```bash
rake test
```
*Runs all files matching `tests/unit/test_*.rb`.*

### Code Coverage (SimpleCov)
Unit tests are instrumented with [SimpleCov](https://github.com/simplecov-ruby/simplecov) to track line coverage.

- **View Summary**: Coverage percentage is printed at the end of `rake test`.
- **View Detailed Report**: Open `coverage/index.html` in your browser.
  ```bash
  open coverage/index.html
  ```
- **Configuration**: See `tests/unit/test_helper.rb` for filtering and grouping options.

---

## 2. Integration Tests (TestUp 2)

Located in `tests/integration/`.

These tests run **inside SketchUp** using the [TestUp 2](https://github.com/SketchUp/testup-2) extension. They verify the actual interaction with the live SketchUp API.

### Available Test Cases

| File | Purpose |
|------|---------|
| `TC_HyperbolicMath.rb` | Core geometry calculations |
| `TC_PresetManager.rb` | Preset save/load with real SketchUp model |
| `TC_ShapeRegistry.rb` | Component tracking and registry |
| `TC_UndoStack.rb` | Undo/Redo integration |
| `TC_AutomatedUndo.rb` | Automated undo stack verification |
| `TC_InteractiveUndo.rb` | Interactive undo prompts |
| `TC_DemoDirector.rb` | Demo automation |
| `TC_DemoDirector_Undo.rb` | Demo with undo verification |
| `TC_ZZZ_Verification.rb` | Post-test verification (runs last) |

### Prerequisites
- Install [TestUp 2](https://github.com/SketchUp/testup-2) in SketchUp.
- Configure TestUp 2 to point to the `tests` directory of this project.

### How to Configure TestUp 2
1. Open SketchUp.
2. Go to **Extensions > TestUp 2 > Preferences**.
3. Under **Test Suite Paths**, add the path to this project's `tests/` directory.
4. Click **Save**.

### How to Run
1. Open SketchUp.
2. Open **Extensions > TestUp 2 > TestUp**.
3. Select the `JtHyperbolicCurves` test suite.
4. Click **Run Tests**.

### Verification (The Bridge)
Since integration tests run manually in SketchUp, you must "sign off" that they passed before publishing a release.

**Recommended Method**: Run the `TC_ZZZ_Verification.rb` test case in TestUp *after* all other tests pass. This test case automatically records the current commit hash.

**Legacy/Fallback**:
```bash
rake test:mark_integration_passed_manual  # DEPRECATED
```

*`rake publish` will warn you if you try to publish a commit that hasn't been verified.*

---

## 3. Tooling Integrity (Meta-Tests)

Located in `tests/meta/`.

These tests verify the reliability of the build and deployment tools themselves (e.g., verifying that the "Integrity Check" actually fails when files are corrupted).

### How to Run
```bash
rake test:meta
```

This runs:
1. `tests/meta/test_build_integrity.rb` — IntegrityCheck class tests
2. `tools/verify_build.rb` — Full build pipeline verification

---

## 4. Run All Tests

To run both unit tests and meta-tests in one command:
```bash
rake test:all
```

This is useful for CI or before committing to ensure nothing is broken.

---

## 5. Linting

We use `rubocop` with strict rules, including `rubocop-sketchup` for extension best practices.

### How to Run
```bash
rake lint
```
*Note: `tools/`, `tests/`, and `tasks/` directories are excluded from SketchUp-specific rules (like `exit` bans) but are still checked for standard Ruby style.*

---

## 6. Development Mode Logging

When running `rake dev`, the extension is loaded with:
- **Automatic Console Open**: The Ruby Console opens immediately to show logs.
- **Console Logging**: `JtHyperbolicCurves::Debug.log` outputs to the console (prefixed with `[HC Debug]`).
- **File Logging**: Logs are also written to `test_logs/ui_debug.log` if the folder exists.
