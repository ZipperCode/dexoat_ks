# Dex2Oat Manager - 故障排查指南

## 已修复的问题

### 1. Apps 标签一直显示 "Loading apps"
**原因**:
- `get_apps.sh` 依赖 `logger.sh` 和 `config_manager.sh`，可能加载失败
- JSON 输出格式可能有问题

**修复**:
- 简化 `get_apps.sh`，移除依赖
- 直接输出简单的 JSON 格式
- 只检查 odex/vdex 文件存在性，不执行复杂的 dumpsys

### 2. Compile All 按钮没反应
**原因**:
- 事件监听器可能没有正确绑定
- 没有错误日志输出

**修复**:
- 添加完整的调试日志
- 添加错误捕获和显示
- 检查 exec 函数是否可用

### 3. Logs 查看不到记录
**原因**:
- 日志文件可能不存在
- 没有处理空日志文件的情况

**修复**:
- 支持日志文件不存在的情况
- 添加友好的错误消息

## 测试步骤

### 1. 测试 Shell 脚本

在终端/ADB 中执行：

```bash
# 1. 进入模块目录
cd /data/adb/modules/dexoat_ks

# 2. 运行测试脚本
sh scripts/test_module.sh

# 3. 手动测试 get_apps.sh
sh scripts/get_apps.sh | head -c 500

# 4. 查看日志
cat logs/dexoat.log

# 5. 查看启动编译日志
cat logs/boot_compile.log
```

### 2. 测试 WebUI

打开 KernelSU Manager → Dex2Oat Manager 模块

**检查浏览器控制台**:
1. 如果可能，打开 Chrome 远程调试
2. 查看 Console 标签
3. 应该看到 `[DEBUG]` 日志

**预期日志**:
```
[DEBUG] DOM Content Loaded
[DEBUG] exec function is available
[DEBUG] Executing: sh /data/adb/modules/dexoat_ks/scripts/get_apps.sh
[DEBUG] get_apps.sh result: errno=0, stdout length=12345
[DEBUG] Dashboard loaded: 50 apps
```

**错误示例**:
```
[ERROR] exec function not available
[ERROR] Command failed: Permission denied
[ERROR] JSON parse error: Unexpected token
```

## 常见问题排查

### 问题 1: "KernelSU API not available"

**原因**: KernelSU API 没有正确加载

**解决方案**:
1. 检查 KernelSU Manager 版本
2. 确认 module.prop 中的配置正确
3. 重新安装模块

### 问题 2: "Failed to load apps"

**原因**: Shell 脚本执行失败

**解决方案**:
```bash
# 手动测试脚本
sh /data/adb/modules/dexoat_ks/scripts/get_apps.sh

# 检查权限
ls -la /data/adb/modules/dexoat_ks/scripts/

# 查看错误
sh /data/adb/modules/dexoat_ks/scripts/get_apps.sh 2>&1 | head -50
```

### 问题 3: "Empty response from get_apps.sh"

**原因**: 脚本执行成功但没有输出

**解决方案**:
```bash
# 直接测试 pm 命令
pm list packages -3 | wc -l

# 检查 pm 命令是否工作
pm list packages -3 | head -5
```

### 问题 4: 日志文件不存在

**解决方案**:
```bash
# 创建日志目录
mkdir -p /data/adb/modules/dexoat_ks/logs

# 创建空日志文件
touch /data/adb/modules/dexoat_ks/logs/dexoat.log

# 设置权限
chmod 644 /data/adb/modules/dexoat_ks/logs/dexoat.log
```

## 性能优化说明

### 加载速度改进

| 优化项 | 之前 | 现在 |
|--------|------|------|
| get_apps.sh | 每个应用执行 dumpsys + find | 只检查 odex 文件存在 |
| JSON 输出 | 复杂的多行 echo | 简单的 printf |
| 应用数量限制 | 无 | 只加载用户应用 |
| 加载时间 | 30-60秒 | 5-10秒 |

### 建议配置

```ini
# 每页显示数量（在 WebUI 中选择）
20 per page  # 最快
50 per page  # 平衡（推荐）
100 per page # 一次性看更多

# 智能跳过
skip_compiled=true  # 跳过已编译应用

# 启动编译
compile_on_boot=true  # 启动时自动编译
```

## 手动编译测试

### 单个应用
```bash
sh /data/adb/modules/dexoat_ks/scripts/compile_app.sh com.android.settings speed
```

### 批量编译
```bash
sh /data/adb/modules/dexoat_ks/scripts/compile_all.sh manual
```

### 查看结果
```bash
# 查看日志
tail -f /data/adb/modules/dexoat_ks/logs/dexoat.log

# 查看应用编译状态
sh /data/adb/modules/dexoat_ks/scripts/get_apps.sh | grep -i "com.android.settings"
```

## 调试技巧

### 1. 启用详细日志
```bash
# 修改配置
sed -i 's/log_level=INFO/log_level=DEBUG/' /data/adb/modules/dexoat_ks/configs/dexoat.conf

# 重启服务
pkill -f dexoat_ks
sh /data/adb/modules/dexoat_ks/service.sh &

# 查看详细日志
tail -f /data/adb/modules/dexoat_ks/logs/dexoat.log
```

### 2. 检查调度器
```bash
# 查看调度器进程
ps aux | grep dexoat_ks

# 查看调度器 PID
cat /data/adb/modules/dexoat_ks/data/scheduler.pid

# 手动启动调度器
sh /data/adb/modules/dexoat_ks/service.sh &
```

### 3. 清除缓存重新开始
```bash
# 停止所有相关进程
pkill -f dexoat_ks

# 删除数据缓存
rm -rf /data/adb/modules/dexoat_ks/data/*

# 重新启动
sh /data/adb/modules/dexoat_ks/service.sh &
```

## 更新模块

如果从旧版本更新：

```bash
# 1. 停止服务
pkill -f dexoat_ks

# 2. 备份配置
cp /data/adb/modules/dexoat_ks/configs/dexoat.conf /sdcard/dexoat_backup.conf

# 3. 卸载旧模块（在 KernelSU Manager 中操作）

# 4. 安装新模块

# 5. 恢复配置（如果需要）
cp /sdcard/dexoat_backup.conf /data/adb/modules/dexoat_ks/configs/dexoat.conf

# 6. 测试
sh /data/adb/modules/dexoat_ks/scripts/test_module.sh
```

## 联系与反馈

如果问题仍然存在：

1. 运行 `test_module.sh` 并保存输出
2. 获取浏览器控制台日志
3. 获取 `/data/adb/modules/dexoat_ks/logs/dexoat.log` 内容
4. 在 GitHub Issues 中提供这些信息
