# 发布说明（中文）

## 2025-10-13
本次更新聚焦“导航监听调试效率提升”和“蓝牙权限修复”，并完善页面工具。

### 新增与优化
- 导航页面
  - 启动监听前显式设置标准 Actions：AUTONAVI_STANDARD_BROADCAST_SEND / RECV，确保动态接收器正确注册。
  - AppBar 新增“调试”按钮：
    - 一键设置标准 Actions
    - 一键发送测试广播（验证接收链路）
  - 保留并完善：清空数据、复制信息、缓存管理按钮；底部导航采用 IndexedStack 保持页面状态。
- 蓝牙
  - AndroidManifest 新增 Android 12+ 蓝牙权限：BLUETOOTH_SCAN / CONNECT / ADVERTISE，并兼容旧版 BLUETOOTH / ADMIN（maxSdkVersion=30），解决可能导致扫描结果为空的问题。
  - 已基于 flutter_blue_plus 扫描与连接真实设备（需开启系统蓝牙与定位服务并授予权限）。
- 原生通道
  - MainActivity 已确认调用 AmapNavBridge.setup(...)，确保 MethodChannel / EventChannel 正常工作。

### 使用建议
- 导航监听调试：
  1) 打开“导航监听”页 -> “调试” -> “发送测试广播”，应出现自然语言导航描述。
  2) 进入真实导航后，应持续收到广播并更新列表。
- 蓝牙扫描：
  1) 确保系统蓝牙与定位服务开启，并在首次进入授予相关权限。
  2) 打开“蓝牙控制”页 -> “开始扫描”，应看到附近设备并可尝试连接。

### 后续计划
- 若部分车机厂商 Action/Extras 存在差异，将支持运行时自定义 Actions 与键位映射，以提升适配性。
- 如需开启混淆压缩，将补充 com.amap.api.** 等 keep 规则，避免 R8 误删类。