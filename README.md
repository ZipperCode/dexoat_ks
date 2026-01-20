# Dex2Oat Manager - KernelSU Module

A comprehensive KernelSU module for managing Android app dex2oat compilation with a WebUI interface, scheduled compilation, smart detection, and comprehensive logging.

## Features

- 🎯 **WebUI Interface**: Modern, responsive web interface integrated with KernelSU Manager
- ⏰ **Scheduled Compilation**: Cron-like automation for regular compilation tasks
- 🧠 **Smart Detection**: Skip already compiled apps, detect mode resets after updates
- ⚙️ **Configuration Management**: Per-app rules, flexible configuration options
- 📝 **Comprehensive Logging**: Detailed logs with rotation support
- 🔄 **Batch Operations**: Compile multiple apps at once
- 🗑️ **Cleanup Tools**: Un-compile all apps to reset to default state

## Requirements

- **Android Version**: 13, 14, or 15
- **KernelSU**: Latest version with WebUI support
- **Root Access**: Required for dex2oat operations

## Installation

1. Copy the entire `dexoat-ks` directory to your device
2. Install via KernelSU Manager:
   - Open KernelSU Manager
   - Go to Modules tab
   - Install from storage
   - Select the module zip file
3. Reboot the device
4. Open KernelSU Manager → Modules → Dex2Oat Manager

## Module Structure

```
dexoat-ks/
├── module.prop              # Module metadata
├── service.sh               # Boot script (scheduler daemon)
├── uninstall.sh             # Cleanup script
├── configs/
│   ├── dexoat.conf         # Main configuration
│   └── app_rules.conf      # Per-app compilation rules
├── scripts/
│   ├── logger.sh           # Logging utility
│   ├── config_manager.sh   # Configuration management
│   ├── get_apps.sh         # List apps with compilation status
│   ├── compile_app.sh      # Compile single app
│   ├── compile_all.sh      # Batch compilation
│   └── un_compile_all.sh   # Remove all compilations
├── webroot/
│   ├── index.html          # Main WebUI page
│   ├── css/style.css       # Styles
│   └── js/app.js           # Frontend logic
└── logs/
    └── dexoat.log          # Main log file (runtime)
```

## Configuration

### Main Config (`configs/dexoat.conf`)

```ini
# Compilation Settings
default_mode=speed              # speed, verify, speed-profile
skip_compiled=true              # Skip already compiled apps
detect_mode_reset=true          # Detect mode reset after updates

# Schedule Settings (Cron format: minute hour day month weekday)
schedule=0 2 * * *              # Daily at 2 AM
schedule_enabled=false          # Enable/disable scheduling

# Logging Settings
log_level=INFO                  # DEBUG, INFO, WARN, ERROR
log_max_size=5M                 # Max log file size
log_max_files=5                 # Number of rotated logs

# Compilation Rules
compile_system_apps=false       # Include system apps
compile_user_apps=true          # Include user apps
exclude_apps=                   # Comma-separated package names to exclude

# Advanced Settings
parallel_jobs=2                 # Number of parallel compilations
storage_threshold=500           # Minimum free storage (MB)
```

### Per-App Rules (`configs/app_rules.conf`)

```json
{
  "rules": {
    "com.android.chrome": {
      "mode": "speed",
      "enabled": true,
      "priority": 1
    },
    "com.tencent.mm": {
      "mode": "speed-profile",
      "enabled": true,
      "priority": 2
    }
  }
}
```

## Compilation Modes

| Mode | Description | Performance | Compilation Time |
|------|-------------|-------------|------------------|
| **verify** | Basic verification only | Baseline | Fastest |
| **speed** | Balanced optimization | Good | Medium |
| **speed-profile** | Profile-guided optimization | Best | Slowest |

## WebUI Tabs

### Dashboard
- Overview of compilation statistics
- Quick actions (Compile All, Refresh)
- Scheduler status display

### Apps
- List all installed apps
- Filter by type (System/User) and status (Compiled/Uncompiled)
- Search functionality
- Compile individual apps or selected apps

### Schedule
- Enable/disable scheduled compilation
- Configure cron expression
- View next run time
- Manual trigger

### Config
- Configure default compilation mode
- Toggle smart detection features
- Set log level and parallel jobs
- Advanced actions (Un-compile All)

### Logs
- View recent log entries
- Filter by log level
- Download logs
- Clear logs

## Command Line Usage

### Compile Single App
```bash
sh /data/adb/modules/dexoat_ks/scripts/compile_app.sh com.example.app speed
```

### Batch Compilation
```bash
# Manual trigger
sh /data/adb/modules/dexoat_ks/scripts/compile_all.sh manual

# Scheduled trigger
sh /data/adb/modules/dexoat_ks/scripts/compile_all.sh scheduled
```

### List Apps with Status
```bash
sh /data/adb/modules/dexoat_ks/scripts/get_apps.sh
```

### Un-compile All Apps
```bash
sh /data/adb/modules/dexoat_ks/scripts/un_compile_all.sh
```

## Troubleshooting

### Compilation Fails

1. **Check available storage**:
   ```bash
   df -h /data
   ```
   Ensure at least 500MB free space (configurable via `storage_threshold`)

2. **Check logs**:
   ```bash
   cat /data/adb/modules/dexoat_ks/logs/dexoat.log
   ```

3. **Verify package exists**:
   ```bash
   pm list packages | grep com.example.app
   ```

### Scheduler Not Running

1. Check if daemon process is running:
   ```bash
   ps aux | grep dexoat_ks
   ```

2. Restart scheduler:
   ```bash
   pkill -f dexoat_ks
   sh /data/adb/modules/dexoat_ks/service.sh &
   ```

### Mode Reset Not Detected

The mode reset detection compares the current compilation mode with the desired mode from config. If an app was updated and the mode was reset to default, it will be flagged for recompilation.

Check `detect_mode_reset` setting in config:
```bash
grep detect_mode_reset /data/adb/modules/dexoat_ks/configs/dexoat.conf
```

## Uninstallation

1. Open KernelSU Manager
2. Go to Modules tab
3. Find "Dex2Oat Manager"
4. Click Uninstall

The `uninstall.sh` script will:
- Stop all daemon processes
- Remove configuration files
- Remove log files
- Clean up data directory

**Note**: Compiled apps will remain compiled after uninstallation. To remove all compilations, run `un_compile_all.sh` before uninstalling.

## Development

### Adding New Compilation Modes

Edit `scripts/compile_app.sh` and add the new mode to the case statement:

```bash
case $MODE in
  speed)
    COMPILE_MODE="-m speed"
    ;;
  your_new_mode)
    COMPILE_MODE="-m your-new-mode"
    ;;
esac
```

### Modifying WebUI

- **HTML**: `webroot/index.html`
- **CSS**: `webroot/css/style.css`
- **JavaScript**: `webroot/js/app.js`

The WebUI uses the KernelSU JavaScript API (`kernelsu` npm package) to execute shell commands.

## Credits

- **KernelSU**: For the excellent module system and WebUI support
- **Android Open Source Project**: For dex2oat and ART compilation tools

## License

This project is provided as-is for educational and personal use.

## Safety

- Always backup your data before performing system-wide operations
- Test on non-critical apps first
- Monitor logs for any errors
- Ensure sufficient storage space before batch compilation

## Changelog

### v1.0 (Initial Release)
- WebUI interface with 5 tabs
- Scheduled compilation with cron support
- Smart detection (skip compiled, detect mode reset)
- Comprehensive logging with rotation
- Batch compilation support
- Un-compile all functionality
- Per-app compilation rules

## Support

For issues, questions, or contributions, please visit the project repository.
