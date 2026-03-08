# Dex2Oat KernelSU 模块全量重构设计（Android 13-15）

日期：2026-03-08  
状态：已评审确认（讨论稿定版）

## 1. 目标与范围

### 1.1 目标
- 基于当前项目进行全量重构，不做旧实现打补丁。
- 构建可维护、可观测、可恢复的 dex2oat 执行体系，解决“功能混乱和失效”。
- 采用 KernelSU 模块内 WebUI，且前端资源完全离线可用。

### 1.2 兼容范围
- Android：13-15
- Root 体系：KernelSU
- 非目标：Android 12 及以下、Magisk 兼容

### 1.3 触发策略
- 事件驱动优先：应用安装/更新触发编译。
- 定时任务作为补偿机制。
- 手动触发可插队但受规则引擎统一约束。

## 2. 总体架构

采用“核心引擎 + 事件队列 + API 层 + KernelSU WebUI”架构。

### 2.1 组件划分
- `service.sh`：仅负责守护进程拉起、保活、恢复。
- `eventd`：采集安装/更新事件，产出标准事件并入队。
- `queued`：单消费者队列执行器，做去重、重试、状态流转。
- `compiler`：编译执行器，封装 `cmd package compile` 与 SELinux 切换恢复。
- `rule-engine`：统一规则判定（总开关、类型开关、排除名单、模式决策）。
- `api.sh`：WebUI 与 CLI 的唯一业务入口，返回标准 JSON。
- `state-store`：持久化配置、队列、状态、事件、结构化日志。

### 2.2 数据流
1. `eventd` 检测到包变更，写入 `events.jsonl`。
2. 事件经 `rule-engine` 预判后写入 `queue.json`。
3. `queued` 出队并调用 `compiler` 执行。
4. 执行结果写 `state.json` 和 `runtime.jsonl`。
5. WebUI 通过 `api.sh` 拉取状态与日志并展示。

## 3. 规则优先级与状态机

### 3.1 规则语义约定
- 用户口头“白名单”按行为定义为“排除名单”：命中即不编译。

### 3.2 判定顺序
1. `global_enabled=false`：不触发任何编译（仅记录事件）。
2. 命中 `exclude_rules`：`SKIP_EXCLUDED`。
3. 判定应用类型（system/user）。
4. 对应类型开关关闭：`SKIP_SCOPE_DISABLED`。
5. 命中按应用模式规则：使用规则模式。
6. 否则使用全局默认模式。
7. 入执行队列。

### 3.3 触发来源优先级（用于去重与审计）
1. `manual`
2. `event`
3. `schedule`
4. `boot`

### 3.4 任务状态机
- `DISCOVERED` -> `QUEUED` -> `RUNNING` -> `SUCCESS`
- 失败分支：`RUNNING` -> `FAILED_RETRYABLE` ->（重试）-> `SUCCESS/FAILED_FINAL`
- 跳过分支：`DISCOVERED/QUEUED` -> `SKIPPED`

### 3.5 去重与重入队
- 同一包在队列中仅保留最新一条任务。
- 包处于 `RUNNING` 时再次触发：设置 `requeue_after_finish=true`。
- 当前任务结束后自动追加一次执行。
- 默认重试最多 2 次，退避 30s/120s。

## 4. 执行可靠性设计

### 4.1 SELinux 切换与恢复
- 编译前读取当前模式（`getenforce`）。
- 需要时切到 `Permissive`。
- 使用 `trap` 确保成功/失败/中断都恢复原模式。
- 恢复失败写高优先级告警，并暂停后续任务。

### 4.2 并发与锁
- 全局锁：`data/locks/engine.lock`。
- 包级锁：`data/locks/pkg/<package>.lock`。
- 首版单 worker，优先确保稳定与可追踪。

### 4.3 超时与重试
- 默认单任务超时：10 分钟（可配置）。
- 可重试错误：临时 I/O、系统繁忙、SELinux 切换异常。
- 不可重试错误：包不存在、规则拒绝、参数非法。

### 4.4 自愈与恢复
- 心跳文件：`data/health/*.heartbeat`。
- 守护进程超时无心跳则自动拉起。
- 启动恢复：将残留 `RUNNING` 任务改为 `FAILED_RETRYABLE` 并回队列。

### 4.5 原子写入与审计
- 配置写入采用 `tmp -> fsync -> mv`。
- 关键配置变更写审计日志（时间、键、旧值、新值、来源）。

## 5. KernelSU WebUI 设计（离线）

### 5.1 运行约束
- 入口固定：`webroot/index.html`。
- 所有依赖文件随模块打包，禁止 CDN。
- 前端调用 KernelSU 提供 API（`exec`）执行 `api.sh`。

### 5.2 页面结构
- 总览：队列长度、成功率、耗时、失败原因 TopN。
- 应用策略：系统/三方开关、排除名单、按应用模式。
- 任务中心：实时队列、运行中、重试队列、插队执行。
- 事件中心：安装/更新事件流及规则命中原因。
- 日志与诊断：结构化过滤、导出诊断包。

### 5.3 API 约定
统一入口：`scripts/api.sh`  
返回结构：`{ "success": bool, "code": string, "message": string, "data": object }`

核心接口：
- `get_config`
- `set_config --key --value`
- `list_apps --type --page --size --search`
- `upsert_rule --package --mode --enabled`
- `delete_rule --package`
- `enqueue --package --source`
- `queue_status`
- `task_history --page --size`
- `event_history --page --size`
- `logs --level --since`
- `diagnostics_export`

### 5.4 前端原则
- 禁止直接 `sed/cat` 配置文件。
- 关键危险操作必须二次确认。
- 前端只做展示与基本校验，业务逻辑由后端统一判定。

## 6. 状态与数据模型

- `data/config.json`：全局配置。
- `data/rules.json`：按应用规则（排除/模式）。
- `data/queue.json`：待执行队列。
- `data/state.json`：每包最后状态与统计。
- `data/events.jsonl`：事件流。
- `logs/runtime.log`：文本日志。
- `logs/runtime.jsonl`：结构化日志。

## 7. 里程碑与验收

### 7.1 里程碑
- M1：核心引擎跑通（CLI 可用）。
- M2：API 层稳定（前后端解耦）。
- M3：KernelSU WebUI 离线交付。
- M4：稳定性强化与回归。

### 7.2 必测项
- 规则优先级冲突场景。
- 事件触发、去重、重入队。
- SELinux 切换恢复全路径。
- 三类执行结果：成功/可重试失败/最终失败。
- API 输出一致性与原子写入。
- WebUI 在 KernelSU 内离线可用。

### 7.3 DoD
- 连续 48 小时运行无守护进程泄漏。
- 100 次随机事件触发无任务丢失或重复执行。
- 日志可定位失败根因（包名、触发源、错误码、阶段）。
- WebUI 与 CLI 状态一致。

## 8. 回滚策略

- 保留 `legacy` 分支快照。
- 新旧状态目录隔离。
- 提供一键回滚脚本：停新服务 -> 切旧入口 -> 恢复旧配置。

## 9. 风险与验证

### 9.1 主要风险
- 部分机型事件监听不稳定。
- 长时间队列积压导致延迟。
- SELinux 切换失败后状态污染。

### 9.2 验证策略
- 事件监听提供轮询回退路径。
- 对队列长度和任务耗时做阈值告警。
- 每次任务后强制校验 SELinux 状态并记录审计。

