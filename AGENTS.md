# Repository Guidelines

## Project Structure & Module Organization
- `scripts/`: backend shell scripts for compilation, scheduling, config, and logging.
- `configs/`: `dexoat.conf` (main settings) and `app_rules.conf` (per-app JSON rules).
- `webroot/`: WebUI assets (`index.html`, `css/style.css`, `js/app.js`).
- `logs/` and `data/`: runtime directories created on device (kept with `.gitkeep`).
- Root files: `service.sh` (boot/scheduler), `uninstall.sh`, `module.prop`, `update.json`.

## Build, Test, and Development Commands
Run module scripts on-device from `/data/adb/modules/dexoat_ks`.

```bash
sh scripts/test_module.sh             # Sanity-check module installation
sh scripts/test_get_apps.sh           # Validate get_apps.sh JSON output
sh scripts/compile_app.sh com.app speed
sh scripts/compile_all.sh manual
```

Packaging for install:

```bash
zip -r dexoat_ks.zip . -x "*.git*" "*.claude*" "*.spec-workflow*"
```

## Coding Style & Naming Conventions
- Shell: POSIX `sh` with `#!/system/bin/sh`. Prefer small, self-contained scripts. `get_apps.sh` must remain dependency-free (do not source `logger.sh` or `config_manager.sh`).
- WebUI JS: use `const`/`let`, 4-space indentation, and the `execCommand()` wrapper for shell calls. Guard DOM access with null checks.
- CSS/HTML: keep design tokens in `:root` and follow existing class naming in `webroot/`.

## Testing Guidelines
- Tests are manual and device-focused. Use `scripts/test_module.sh` for end-to-end checks and `scripts/test_get_apps.sh` for JSON validation.
- No automated coverage requirements; include a brief test note in PRs.

## Commit & Pull Request Guidelines
- Prefer Conventional Commits as seen in history: `feat:`, `fix:`, `chore:`, `ci:` (e.g., `chore: bump version to v1.0.3`).
- If changing the WebUI, include screenshots or a short GIF in the PR description.
- Link relevant issues and describe device/Android version used for testing.

## Configuration & Release Notes
- Update configs in `configs/` rather than hard-coding values in scripts.
- For releases: bump `module.prop` and `update.json`, then tag `vX.Y.Z`.
