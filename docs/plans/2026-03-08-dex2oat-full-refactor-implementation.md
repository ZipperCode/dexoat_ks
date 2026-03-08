# Dex2Oat KernelSU Full Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Android 13-15 + KernelSU 上交付一个事件驱动优先、规则可控、可恢复、离线 WebUI 的全新 Dex2Oat 模块。

**Architecture:** 新架构分为 `eventd`、`queued`、`compiler`、`rule-engine`、`state-store`、`api.sh`、`KernelSU WebUI` 七层。`service.sh` 仅负责保活和恢复；业务全部通过 API 与引擎层实现。执行路径统一经过规则判定与任务状态机，保证可追踪和可恢复。

**Tech Stack:** POSIX Shell (BusyBox ash), KernelSU WebUI (`window.ksu.exec`), JSON/JSONL 文件存储, git, rg

---

### Task 1: 建立新目录与常量入口

**Files:**
- Create: `scripts/lib/constants.sh`
- Create: `scripts/engine/.gitkeep`
- Create: `data/.gitkeep`
- Modify: `service.sh`
- Test: `scripts/test_module.sh`

**Step 1: 写失败测试（目录与常量存在）**

```sh
# scripts/test_module.sh 末尾追加
[ -f /data/adb/modules/dexoat_ks/scripts/lib/constants.sh ] || {
  echo "[FAIL] constants.sh missing"; exit 1;
}
```

**Step 2: 运行测试并确认失败**

Run: `sh scripts/test_module.sh`  
Expected: FAIL with `constants.sh missing`

**Step 3: 最小实现**

```sh
# scripts/lib/constants.sh
#!/system/bin/sh
MODULE_DIR="/data/adb/modules/dexoat_ks"
DATA_DIR="$MODULE_DIR/data"
LOG_DIR="$MODULE_DIR/logs"
STATE_FILE="$DATA_DIR/state.json"
QUEUE_FILE="$DATA_DIR/queue.json"
CONFIG_FILE="$DATA_DIR/config.json"
RULES_FILE="$DATA_DIR/rules.json"
```

`service.sh` 只保留启动/保活入口（先占位启动，不做业务）。

**Step 4: 运行测试并确认通过**

Run: `sh scripts/test_module.sh`  
Expected: PASS for constants check

**Step 5: Commit**

```bash
git add service.sh scripts/lib/constants.sh scripts/engine/.gitkeep data/.gitkeep scripts/test_module.sh
git commit -m "refactor: scaffold engine layout and constants"
```

### Task 2: 规则引擎（优先级判定）

**Files:**
- Create: `scripts/engine/rule_engine.sh`
- Create: `tests/rule_engine_test.sh`
- Test: `tests/rule_engine_test.sh`

**Step 1: 写失败测试（全局开关与排除名单优先）**

```sh
# tests/rule_engine_test.sh
# case1: global=false => SKIP_GLOBAL_DISABLED
# case2: excluded=true => SKIP_EXCLUDED
# case3: scope off => SKIP_SCOPE_DISABLED
# case4: force mode => EXECUTE:<mode>
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/rule_engine_test.sh`  
Expected: FAIL with `rule_decide not found`

**Step 3: 最小实现**

```sh
# scripts/engine/rule_engine.sh
rule_decide() {
  # 输入: global_enabled app_type scope_enabled excluded forced_mode default_mode
  # 输出: SKIP_* 或 EXECUTE:<mode>
}
```

实现顺序必须固定：全局 -> 排除 -> 类型开关 -> 强制模式 -> 默认模式。

**Step 4: 运行测试并确认通过**

Run: `sh tests/rule_engine_test.sh`  
Expected: PASS all cases

**Step 5: Commit**

```bash
git add scripts/engine/rule_engine.sh tests/rule_engine_test.sh
git commit -m "feat: implement deterministic rule engine precedence"
```

### Task 3: 编译执行器与 SELinux 恢复

**Files:**
- Create: `scripts/engine/compiler.sh`
- Create: `tests/compiler_selinux_test.sh`
- Modify: `scripts/logger.sh`
- Test: `tests/compiler_selinux_test.sh`

**Step 1: 写失败测试（失败路径也必须恢复 SELinux）**

```sh
# tests/compiler_selinux_test.sh
# mock getenforce/setenforce/cmd
# 断言: compile_app_safe 结束后恢复原始模式
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/compiler_selinux_test.sh`  
Expected: FAIL with `SELinux not restored`

**Step 3: 最小实现**

```sh
compile_app_safe() {
  original="$(getenforce 2>/dev/null || echo Enforcing)"
  cleanup(){ [ "$original" = "Enforcing" ] && setenforce 1; [ "$original" = "Permissive" ] && setenforce 0; }
  trap cleanup EXIT INT TERM
  setenforce 0
  cmd package compile -m "$2" "$1"
}
```

**Step 4: 运行测试并确认通过**

Run: `sh tests/compiler_selinux_test.sh`  
Expected: PASS restore checks

**Step 5: Commit**

```bash
git add scripts/engine/compiler.sh tests/compiler_selinux_test.sh scripts/logger.sh
git commit -m "feat: add compile executor with selinux-safe trap restore"
```

### Task 4: 队列与去重/重入队

**Files:**
- Create: `scripts/engine/queue_store.sh`
- Create: `scripts/engine/queued.sh`
- Create: `tests/queue_dedup_test.sh`
- Test: `tests/queue_dedup_test.sh`

**Step 1: 写失败测试（同包只保留最新、运行中触发重入队）**

```sh
# tests/queue_dedup_test.sh
# enqueue A,event
# enqueue A,schedule -> 仍 1 条
# running A + enqueue A,event -> requeue_after_finish=true
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/queue_dedup_test.sh`  
Expected: FAIL with `enqueue_task not found`

**Step 3: 最小实现**

```sh
enqueue_task(){ :; }
mark_running(){ :; }
mark_requeue_after_finish(){ :; }
```

采用文件锁防并发写：`data/locks/engine.lock`。

**Step 4: 运行测试并确认通过**

Run: `sh tests/queue_dedup_test.sh`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/engine/queue_store.sh scripts/engine/queued.sh tests/queue_dedup_test.sh
git commit -m "feat: add queue dedup and requeue-after-finish behavior"
```

### Task 5: 状态存储与原子写

**Files:**
- Create: `scripts/engine/state_store.sh`
- Create: `tests/state_store_atomic_test.sh`
- Test: `tests/state_store_atomic_test.sh`

**Step 1: 写失败测试（写入失败不污染原文件）**

```sh
# tests/state_store_atomic_test.sh
# 模拟写一半失败
# 断言: 原 state.json 保持不变
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/state_store_atomic_test.sh`  
Expected: FAIL with `state_write_atomic not found`

**Step 3: 最小实现**

```sh
state_write_atomic(){
  tmp="$1.tmp.$$"
  printf '%s' "$2" > "$tmp" && sync && mv "$tmp" "$1"
}
```

**Step 4: 运行测试并确认通过**

Run: `sh tests/state_store_atomic_test.sh`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/engine/state_store.sh tests/state_store_atomic_test.sh
git commit -m "feat: add atomic state/config persistence"
```

### Task 6: 事件采集器（eventd）

**Files:**
- Create: `scripts/engine/eventd.sh`
- Create: `tests/eventd_fallback_test.sh`
- Test: `tests/eventd_fallback_test.sh`

**Step 1: 写失败测试（监听失败时回退到轮询）**

```sh
# tests/eventd_fallback_test.sh
# mock inotify 不可用
# 断言: fallback_polling=true
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/eventd_fallback_test.sh`  
Expected: FAIL with `start_eventd not found`

**Step 3: 最小实现**

```sh
start_eventd(){
  if command -v inotifyd >/dev/null 2>&1; then
    # 优先监听
  else
    # 轮询 packages.xml + pm list packages
  fi
}
```

**Step 4: 运行测试并确认通过**

Run: `sh tests/eventd_fallback_test.sh`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/engine/eventd.sh tests/eventd_fallback_test.sh
git commit -m "feat: add event collector with polling fallback"
```

### Task 7: 统一 API（配置与规则）

**Files:**
- Create: `scripts/api.sh`
- Create: `tests/api_config_rules_test.sh`
- Modify: `scripts/config_manager.sh`
- Test: `tests/api_config_rules_test.sh`

**Step 1: 写失败测试（统一 JSON 返回结构）**

```sh
# tests/api_config_rules_test.sh
# sh scripts/api.sh get_config
# 断言包含: success/code/message/data
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/api_config_rules_test.sh`  
Expected: FAIL with `api.sh missing`

**Step 3: 最小实现**

```sh
json_ok(){ printf '{"success":true,"code":"OK","message":"%s","data":%s}\n' "$1" "$2"; }
json_err(){ printf '{"success":false,"code":"%s","message":"%s","data":{}}\n' "$1" "$2"; }
```

实现命令：`get_config`、`set_config`、`upsert_rule`、`delete_rule`。

**Step 4: 运行测试并确认通过**

Run: `sh tests/api_config_rules_test.sh`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/api.sh scripts/config_manager.sh tests/api_config_rules_test.sh
git commit -m "feat: add unified api for config and rules"
```

### Task 8: API（队列与历史）

**Files:**
- Modify: `scripts/api.sh`
- Create: `tests/api_queue_history_test.sh`
- Test: `tests/api_queue_history_test.sh`

**Step 1: 写失败测试（enqueue/queue_status/task_history）**

```sh
# tests/api_queue_history_test.sh
# enqueue -> queue_status -> task_history
# 断言任务可见且字段完整
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/api_queue_history_test.sh`  
Expected: FAIL with `unknown api command`

**Step 3: 最小实现**

```sh
case "$1" in
  enqueue) ;;
  queue_status) ;;
  task_history) ;;
esac
```

**Step 4: 运行测试并确认通过**

Run: `sh tests/api_queue_history_test.sh`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/api.sh tests/api_queue_history_test.sh
git commit -m "feat: add queue and history api endpoints"
```

### Task 9: service 最小化与保活恢复

**Files:**
- Modify: `service.sh`
- Create: `tests/service_recovery_test.sh`
- Test: `tests/service_recovery_test.sh`

**Step 1: 写失败测试（子进程死亡后自动拉起）**

```sh
# tests/service_recovery_test.sh
# mock queued pid 死亡
# 断言 service 触发重拉起
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/service_recovery_test.sh`  
Expected: FAIL with `recovery not triggered`

**Step 3: 最小实现**

```sh
# service.sh
# start eventd/queued
# monitor heartbeat timeout and restart
```

**Step 4: 运行测试并确认通过**

Run: `sh tests/service_recovery_test.sh`  
Expected: PASS

**Step 5: Commit**

```bash
git add service.sh tests/service_recovery_test.sh
git commit -m "refactor: slim service to supervisor and recovery"
```

### Task 10: 重建 KernelSU 离线 WebUI

**Files:**
- Modify: `webroot/index.html`
- Modify: `webroot/js/app.js`
- Modify: `webroot/css/style.css`
- Create: `webroot/js/api-client.js`
- Create: `tests/webui_offline_smoke.md`

**Step 1: 写失败测试（静态检查，不得出现 CDN）**

```sh
# 检查外链
rg -n "cdn|jsdelivr|unpkg|http://|https://" webroot/index.html webroot/js
```

**Step 2: 运行检查并确认失败**

Run: `rg -n "cdn|jsdelivr|unpkg|http://|https://" webroot/index.html webroot/js`  
Expected: FAIL（当前 index.html 存在 jsdelivr）

**Step 3: 最小实现**

- 前端统一调用 `api-client.js`，内部执行：`window.exec('sh .../scripts/api.sh ...')`。
- 替换旧页面为新五大页面：总览、策略、任务、事件、日志诊断。
- 删除所有外链脚本依赖。

**Step 4: 运行检查并确认通过**

Run: `rg -n "cdn|jsdelivr|unpkg|http://|https://" webroot/index.html webroot/js`  
Expected: no output

**Step 5: Commit**

```bash
git add webroot/index.html webroot/js/app.js webroot/js/api-client.js webroot/css/style.css tests/webui_offline_smoke.md
git commit -m "feat: rebuild kernelsu offline webui with api-only calls"
```

### Task 11: 兼容命令与迁移脚本

**Files:**
- Modify: `scripts/compile_all.sh`
- Modify: `scripts/compile_app.sh`
- Modify: `scripts/get_apps.sh`
- Create: `scripts/migrate_legacy_data.sh`
- Create: `tests/legacy_compat_test.sh`

**Step 1: 写失败测试（旧命令仍可用并转发 API）**

```sh
# tests/legacy_compat_test.sh
# sh scripts/compile_all.sh manual
# 断言调用 api enqueue/dispatch 成功
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/legacy_compat_test.sh`  
Expected: FAIL with `legacy command not redirected`

**Step 3: 最小实现**

- 旧脚本改为 shim：只做参数校验 + 转发到 `api.sh`。
- 新增迁移脚本：将旧 `configs/dexoat.conf` 转换到 `data/config.json`。

**Step 4: 运行测试并确认通过**

Run: `sh tests/legacy_compat_test.sh`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/compile_all.sh scripts/compile_app.sh scripts/get_apps.sh scripts/migrate_legacy_data.sh tests/legacy_compat_test.sh
git commit -m "refactor: add legacy command shims and config migration"
```

### Task 12: 全量验证与文档收敛

**Files:**
- Modify: `README.md`
- Modify: `changelog.md`
- Modify: `scripts/test_module.sh`
- Create: `tests/run_all.sh`

**Step 1: 写失败测试（全量脚本汇总）**

```sh
# tests/run_all.sh
set -e
sh tests/rule_engine_test.sh
sh tests/compiler_selinux_test.sh
sh tests/queue_dedup_test.sh
sh tests/state_store_atomic_test.sh
sh tests/eventd_fallback_test.sh
sh tests/api_config_rules_test.sh
sh tests/api_queue_history_test.sh
sh tests/service_recovery_test.sh
sh tests/legacy_compat_test.sh
```

**Step 2: 运行测试并确认失败**

Run: `sh tests/run_all.sh`  
Expected: FAIL（至少一个子项失败）

**Step 3: 最小实现**

- 修复未通过项直至 `run_all.sh` 全绿。
- 文档补齐：新架构、API、WebUI、迁移与回滚说明。

**Step 4: 运行测试并确认通过**

Run: `sh tests/run_all.sh && sh scripts/test_module.sh`  
Expected: PASS all

**Step 5: Commit**

```bash
git add README.md changelog.md scripts/test_module.sh tests/run_all.sh
git commit -m "docs: finalize refactor docs and verification suite"
```

## 执行顺序与约束

- 执行顺序：Task 1 -> Task 12，禁止跨层跳步。
- 每个 Task 必须遵循 `@superpowers/test-driven-development`：先失败测试，再最小实现。
- 每个 Task 完成前必须执行 `@superpowers/verification-before-completion`。
- 实施阶段建议使用 `@superpowers/subagent-driven-development`，每个 Task 独立子代理执行并人工复核。

## 回滚检查点

- Task 4 后打一个里程碑标签：`refactor-m1-core-engine`。
- Task 8 后打一个里程碑标签：`refactor-m2-api`。
- Task 10 后打一个里程碑标签：`refactor-m3-webui`。

## 交付产物

- 新引擎脚本与测试套件。
- 统一 API 与离线 WebUI。
- 兼容 shim 与迁移脚本。
- 更新后的 README/changelog/诊断与回滚说明。
