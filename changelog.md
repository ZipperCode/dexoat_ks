# Changelog

## [Unreleased] - 2026-03-08

### Added
- 新增核心引擎目录 `scripts/engine`：规则引擎、编译执行器、队列存储、事件采集、状态原子写。
- 新增统一 API `scripts/api.sh`，提供配置、规则、队列、历史接口。
- 新增离线 WebUI API 客户端 `webroot/js/api-client.js`。
- 新增测试套件：`tests/run_all.sh` 及各子测试脚本。
- 新增旧配置迁移脚本 `scripts/migrate_legacy_data.sh`。

### Changed
- `service.sh` 重构为 supervisor 模型，支持子进程故障恢复。
- `webroot/` 重建为离线可用的 KernelSU 模块 WebUI。
- 旧入口脚本 `compile_all.sh` / `compile_app.sh` / `get_apps.sh` 改为 API shim。

### Notes
- 本次为架构级重构，建议升级后先执行一次 `scripts/test_module.sh` 与 `tests/run_all.sh`。
