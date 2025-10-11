版本 v3.0.1+3（中文说明）

一、已完成的核心改造
- 底部导航栏：BottomNavigationBar + IndexedStack，切换稳定不重建。
- 导航监听页（高德）：展示监听数据，术语转通俗、路线 JSON 转自然语言、状态码转中文，隐藏技术字段，突出关键信息（下一步动作、道路、剩余距离/时间、时速/限速、目的地）。
- 操作按钮：清空数据、复制信息、缓存管理（保留最近100条，SharedPreferences 持久化）。
- 蓝牙控制页：使用 flutter_blue_plus 替代模拟设备，支持真实设备扫描/连接；集成运行时权限。
- Android 构建：AGP 8.2.2 + Gradle 8.2，修复命名空间（namespace）问题；为旧式插件补充 ext.flutter；R8 收敛并为 AMap 依赖补充仓库与兼容配置。

二、本次修复（广播与蓝牙）
- 高德“标准广播”监听增强：
  1) Manifest 静态注册接收器，支持多 Action（SEND/RECV）、带/不带 Category，提升优先级（priority=1000）。
  2) 原生桥接（AmapNavBridge）：缓存最近一次事件，Flutter 订阅后立刻补发；动态注册同样支持多 Action；加入原生日志便于排查。
- 蓝牙兼容性增强：
  - Manifest 新增 uses-feature（bluetooth / bluetooth_le，均为 required=false），提升设备枚举兼容性。
  - 保持 Android 12+ 权限（BLUETOOTH_SCAN / CONNECT）与定位权限；需确保系统“定位服务”开启。

三、当前已知问题与建议
- 广播数据未收到：
  - 厂商车机/ROM 可能使用定制 Action/Category，或限制第三方接收。建议提供实际广播 Action 名称（由厂商文档或原生抓包得出），以便加入白名单。
  - 兜底方案：集成 AMapNavi SDK 回调（AMapNaviListener），绕过广播差异。若确认，需要我为 Android 侧补充最小桥接实现（EventChannel 推送）。
- 蓝牙“无法获取设备”：
  - 请确认：系统蓝牙已开；系统定位服务已开（Android 12+ 扫描依赖）；应用已授予“附近设备”“蓝牙扫描/连接”“定位”权限。
  - 部分设备需开启“后台定位/自启动/省电策略豁免”，否则扫描窗口会受限。
  - 若仍异常，请提供一次运行日志（logcat）或报错信息，我将定向排查（扫描回调异常、权限拒绝、适配器状态等）。

四、后续计划（可选）
- 实施 AMapNaviListener 回调桥接，确保在广播不可用的设备上也能稳定产出导航数据。
- 若需要开启混淆（R8），将补充 AMap 相关 keep 规则，确保类不被裁剪。
- 在蓝牙页加入“定位服务状态检测”与“引导开启定位服务”的提示，降低用户使用门槛。

五、测试建议
- 广播自测命令（需真机/ADB）：
  adb shell am broadcast -a AUTONAVI_STANDARD_BROADCAST_SEND -c AUTONAVI_STANDARD_CATEGORY --es KEY_ACTION "turn-left" --es EXTRA_ROAD_NAME "人民路" --es EXTRA_NEXT_ROAD_NAME "解放路" --ei EXTRA_REMAIN_DISTANCE 850 --ei EXTRA_REMAIN_TIME 120 --ei EXTRA_CUR_SPEED 38 --ei EXTRA_LIMIT_SPEED 60
- 查看日志：
  adb logcat | findstr AmapBroadcastReceiver
  adb logcat | findstr AmapNavBridge

如需我继续实现 AMapNavi SDK 回调桥接，请明确同意，我将直接提交实现并保持与现有 Flutter 通道一致。