# 更新日志

## 版本 3.1.0+1 (2025-10-13)

### 新增功能
- ✅ 导航栏底部布局优化，使用BottomNavigationBar + IndexedStack
- ✅ 高德地图导航监听页面实时显示导航数据
- ✅ 专业术语转换为通俗易懂的中文表述
- ✅ 路线详情JSON数据转化为自然语言描述
- ✅ 状态码转换为文字说明
- ✅ 隐藏技术性字段，突出关键导航信息
- ✅ 新增功能按钮：清空数据、复制信息、缓存管理
- ✅ 蓝牙控制页面使用flutter_blue_plus替换模拟设备
- ✅ 实现真实蓝牙设备的显示与交互

### 技术优化
- ✅ 使用EventChannel实时接收高德地图导航数据
- ✅ NavigationDataConverter数据转换器完善
- ✅ BluetoothService蓝牙服务完整实现
- ✅ 缓存管理使用SharedPreferences持久化
- ✅ 代码质量优化，Flutter分析无问题

### 依赖更新
- flutter_blue_plus: ^1.36.8
- amap_flutter_location: 3.0.0
- amap_flutter_map: ^3.0.0
- shared_preferences: ^2.3.3

## 版本 3.0.2+4 (历史版本)
- 基础功能实现
- 初始项目结构搭建