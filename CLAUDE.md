# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dex2Oat Manager is a KernelSU module for Android that manages dex2oat compilation of applications. It provides a WebUI for users to control compilation, schedule automated tasks, and monitor compilation status.

### Key Architecture

**KernelSU Module Structure**:
- `service.sh` - Executed by KernelSU on boot, runs scheduler daemon and optional boot compilation
- `uninstall.sh` - Cleanup script executed when module is uninstalled
- `module.prop` - KernelSU module metadata
- `webroot/` - WebUI files served by KernelSU Manager (must have index.html)
- `configs/` - Configuration files (dexoat.conf for main config, app_rules.conf for per-app rules)
- `scripts/` - Shell scripts for backend operations
- `logs/` - Runtime log files (created at runtime, not in git)

**Execution Flow**:
1. Device boots → KernelSU loads module → runs `service.sh`
2. `service.sh` waits for boot completion, checks `compile_on_boot` config, starts scheduler daemon
3. Scheduler daemon runs in background checking cron schedule every minute
4. WebUI communicates via KernelSU JavaScript API (`window.exec()`) to run shell scripts
5. Shell scripts log to `/data/adb/modules/dexoat_ks/logs/dexoat.log`

## Common Development Commands

### Module Development

```bash
# Test the module on device
cd /data/adb/modules/dexoat_ks
sh scripts/test_module.sh

# Run individual scripts
sh scripts/get_apps.sh              # List apps with status (JSON output)
sh scripts/compile_app.sh com.example.app speed  # Compile single app
sh scripts/compile_all.sh manual      # Batch compile
sh scripts/un_compile_all.sh        # Remove all compilations

# View logs
cat logs/dexoat.log                 # Main log
cat logs/boot_compile.log           # Boot compilation log

# Restart scheduler
pkill -f dexoat_ks
sh service.sh &

# Check scheduler status
ps aux | grep dexoat_ks
cat data/scheduler.pid
```

### Building Module Package

```bash
# Create zip package for installation
zip -r dexoat_ks.zip . -x "*.git*" "*.claude*" "*.spec-workflow*"

# Install via KernelSU Manager (on device)
# Then transfer and flash the zip file
```

### Testing Shell Scripts

```bash
# Test get_apps.sh output
sh scripts/get_apps.sh | jq .  # Requires jq on device
sh scripts/get_apps.sh | head -c 200  # Preview output

# Verify JSON validity
sh scripts/get_apps.sh | python3 -m json.tool  # On host machine

# Test logger
sh -c '. scripts/logger.sh && log_info "Test message"'

# Test compilation with a test app
sh scripts/compile_app.sh com.android.settings speed
```

### WebUI Development

The WebUI uses the KernelSU JavaScript API imported from CDN:
```javascript
import { exec } from 'https://cdn.jsdelivr.net/npm/kernelsu@latest/index.js';
```

**Key patterns**:
- All shell commands executed via `window.exec(command)` returns `{errno, stdout}`
- Use `logDebug()` to output to browser console for debugging
- Use `showToast()` to display user-facing messages
- All DOM access should check for null/undefined elements
- Tab data is lazy-loaded (only loaded when tab is clicked)

## Important Architecture Decisions

### Shell Script Dependencies

**Critical**: `scripts/get_apps.sh` MUST NOT depend on `logger.sh` or `config_manager.sh`

**Reason**: When WebUI loads apps, it calls `get_apps.sh` directly. If this script sources other scripts that fail or have errors, the entire JSON output breaks, causing "Loading apps..." to hang forever.

**Current design**:
- `get_apps.sh` is completely self-contained, no dependencies
- Uses `grep` to read config directly instead of `config_manager.sh`
- Outputs JSON using `echo` and `printf` directly
- Only checks for odex/vdex file existence (fast, no dumpsys)

**Other scripts** (compile_app.sh, compile_all.sh, service.sh) DO depend on logger.sh and config_manager.sh because they run in controlled environments.

### Compilation Status Detection Strategy

The module uses a fast-but-imprecise approach for listing apps:

1. Uses `pm path $package` to get APK location (faster than dumpsys)
2. Checks if oat directory exists and contains odex/vdex files
3. If files exist → assumes "compiled" with "speed" mode
4. Does NOT query actual compilation mode from dumpsys (too slow for 100+ apps)

**Trade-off**: Fast loading (5-10s) vs accurate mode detection. Users see "speed" for all compiled apps even if actual mode differs. Mode reset detection feature relies on this simplified model.

### Scheduler Implementation

Android doesn't have cron, so `service.sh` implements a custom scheduler:

1. Runs as background daemon process after boot
2. Checks cron schedule every 60 seconds
3. Uses `should_run_now()` function to match current time against schedule
4. Supports wildcards (*) and ranges (e.g., 1-5) in cron expressions
5. Tracks last run day to prevent multiple daily executions

### Boot Compilation Flow

1. `service.sh` waits for `sys.boot_completed=1` (max 5 minutes)
2. Checks `compile_on_boot` config
3. Checks if already compiled today (uses marker file `boot_compiled_YYYYMMDD`)
4. If not compiled, spawns background compilation with 30s delay
5. Compilation runs in background, logs to `logs/boot_compile.log`

## Configuration System

Config files use simple key=value format parsed with `grep` and `cut`:

```bash
get_config() {
  key=$1
  grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-
}
```

**No complex parsing**: Avoids jq, source, or other dependencies that could fail.

## Logging System

Logger (`scripts/logger.sh`) provides four levels: DEBUG, INFO, WARN, ERROR

**Important**: Log level is checked BEFORE logging (via `should_log()`). Default is INFO. Change via `log_level=` in config.

Log rotation happens in `service.sh` on startup:
- Checks if `dexoat.log` exceeds 5MB
- If so, shifts .1 → .2, .2 → .3, etc.
- Moves current log to .1
- Keeps max 5 rotated logs

## WebUI Tab Architecture

The WebUI uses a single-page app (SPA) approach with lazy loading:

1. **Dashboard** - Loaded on page load, shows compilation statistics
2. **Apps** - Loaded when tab clicked, shows paginated app list (20/50/100 per page)
3. **Schedule** - Loaded when tab clicked, shows cron config
4. **Config** - Loaded when tab clicked, shows all settings
5. **Logs** - Loaded when tab clicked, shows last 50 log lines

**Performance optimization**: Apps tab uses pagination (default 50 apps per page) to avoid rendering 100+ app cards at once. Search is debounced (300ms).

## Error Handling Philosophy

**Shell scripts**:
- Always check command exit codes (`$?`)
- Use `2>/dev/null` to suppress expected errors
- Return JSON for errors: `{\"success\": false, \"error\": \"message\"}``
- Log all operations via logger.sh

**JavaScript**:
- Wrap all async operations in try-catch
- Check `result.errno` from exec calls
- Use optional chaining (`?.`) for all DOM access
- Log debug messages to console for troubleshooting
- Display errors via toast messages

## Critical Gotchas

1. **Never modify get_apps.sh to depend on other scripts** - This will break WebUI loading
2. **Always ensure scripts are executable** - Use `chmod +x` for all .sh files
3. **Log rotation only happens on module boot** - Not during normal operation
4. **Scheduler PID file** - Used to prevent duplicate scheduler instances
5. **Boot marker files** - Named `boot_compiled_YYYYMMDD` to prevent multiple daily compilations
6. **WebUI CDN** - KernelSU API loaded from jsdelivr, requires internet connection on device
7. **JSON parsing in shell** - No jq dependency, manual parsing with grep/cut/awk
8. **Background processes** - Use `&` to spawn, `disown` to detach from parent
