# Changelog

## [1.0.4] - 2026-02-08

### Added
- Backend pagination for Apps list to reduce initial load time
- Config toggles to include/exclude system and third-party apps in batch compilation
- AGENTS.md contributor guide

### Fixed
- Batch compilation JSON parsing for paginated app list responses

## [1.0.1] - 2025-01-22

### Added
- GitHub Actions workflow for automatic package building and releases
- Automatic update.json management via GitHub Actions
- SELinux permissive mode handling for compilation
  - Single app: set permissive before compile, restore enforcing after
  - Batch compile: set permissive once before all apps, restore after all done
- Changelog.md for version history tracking

## [1.0] - 2025-01-22

### Initial Release
- WebUI for managing app dex2oat compilation
- Schedule automated compilation tasks
- Monitor compilation status with comprehensive logging
- Smart detection of compiled apps
- Boot compilation support
- Configuration management
