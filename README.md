# Dex2Oat Control - KernelSU Module

Dex2Oat 全量重构版（Android 13-15, KernelSU）。

## 核心设计

- 事件驱动优先：安装/更新触发入队。
- Supervisor 服务：`service.sh` 仅负责拉起与恢复 `eventd/queued`。
- 规则引擎：全局开关 -> 排除规则 -> 范围开关 -> 强制模式 -> 默认模式。
- 统一 API：`scripts/api.sh`，WebUI 和脚本统一走 API。
- 离线 WebUI：`webroot/` 全本地资源，无 CDN。

## 目录

- `scripts/engine/`：核心引擎（规则、队列、事件、编译、状态）。
- `scripts/api.sh`：统一 API 入口。
- `scripts/migrate_legacy_data.sh`：旧配置迁移。
- `webroot/`：KernelSU WebUI 离线前端。
- `tests/`：本地可执行测试集合。

## 常用命令

```bash
# 全量测试
sh tests/run_all.sh

# 读取配置
sh scripts/api.sh get_config

# 设置配置
sh scripts/api.sh set_config --key global_enabled --value true

# 入队任务
sh scripts/api.sh enqueue --package com.example.app --source manual

# 队列状态
sh scripts/api.sh queue_status
```

## 设备侧验证

```bash
adb devices
adb shell "su -c 'sh /data/adb/modules/dexoat_ks/scripts/test_module.sh'"
```

## 兼容说明

- 旧命令入口已转发到 API：`compile_all.sh`、`compile_app.sh`、`get_apps.sh`。
- 迁移脚本会把 `configs/dexoat.conf` 的键值写入新配置存储。
