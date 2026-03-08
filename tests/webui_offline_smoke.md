# WebUI Offline Smoke

## 1. 本地静态检查

```bash
rg -n "cdn|jsdelivr|unpkg|http://|https://" webroot/index.html webroot/js
```

预期：无输出。

## 2. 设备侧冒烟

```bash
adb shell "su -c 'ls -la /data/adb/modules/dexoat_ks/webroot'"
adb shell "su -c 'grep -R -n \"jsdelivr\|https://\" /data/adb/modules/dexoat_ks/webroot || true'"
```

预期：`webroot` 文件存在，且无外链脚本。

## 3. KernelSU WebUI 打开检查

- 在 KernelSU Manager 打开模块 WebUI。
- 检查页面可渲染并可切换五个标签页。
- 触发“刷新总览”“刷新队列”“刷新日志”不报错。
