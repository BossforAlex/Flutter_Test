# AmapAuto 导航监听器 - Flutter 应用

## 项目概述
一个用于监听和显示高德地图导航数据的 Flutter 应用程序，提供实时导航监控、数据智能转换和蓝牙设备交互功能。

## 主要功能
- 📍 **底部导航栏**：导航栏置于页面底部，支持页面状态保持
- 🗺️ **实时导航监听**：监听高德地图导航数据，专业术语转通俗中文
- 📝 **智能数据转换**：JSON数据转自然语言描述，状态码转文字说明
- 🔍 **关键信息突出**：隐藏技术字段，突出显示关键导航信息
- 📋 **数据管理功能**：清空数据、复制信息、缓存管理
- 📱 **蓝牙设备交互**：使用flutter_blue_plus实现真实蓝牙设备显示与交互
- 🎨 **Material 3 设计**：现代化的用户界面设计

## 技术特性
- **Flutter Framework**：使用最新的 Material 3 设计规范
- **BottomNavigationBar + IndexedStack**：底部导航栏布局，页面状态保持
- **EventChannel/MethodChannel**：与高德地图原生平台通信
- **NavigationDataConverter**：专业数据智能转换和自然语言描述
- **flutter_blue_plus**：蓝牙设备扫描、连接、数据交互
- **SharedPreferences**：数据缓存持久化管理

## 快速开始

### 环境要求
- Flutter SDK 3.0.0+
- Android SDK
- 有效的 Flutter 开发环境

### 构建命令
```bash
# 调试版本
flutter build apk --debug

# 发布版本
flutter build apk --release
```

### 运行应用
```bash
flutter run
```

## 项目结构
```
lib/
├── main.dart              # 主应用程序文件
├── broadcast_deduplicator.dart  # 智能去重管理器
└── ...
```

## 核心组件

### AmapAutoListenerApp
主应用程序类，配置 Material 3 主题和底部导航栏。

### NavigationListenerPage
导航监听页面，包含：
- 高德地图导航数据实时监听
- 专业数据智能转换和显示
- 清空、复制、缓存管理功能

### BluetoothPage
蓝牙控制页面，包含：
- 真实蓝牙设备扫描和显示
- 设备连接、数据读写操作
- 服务特征值管理

### NavigationDataConverter
数据转换器，实现：
- 状态码转文字说明
- JSON数据转自然语言描述
- 专业术语转通俗中文表述

## 数据格式
应用支持多种数据类型：
- 导航数据 (onNavigationData)
- 位置数据 (onLocationData)  
- 标准广播数据 (onStandardBroadcast)
- 未知广播数据 (onUnknownBroadcast)

## 版本信息
- **当前版本**: 3.1.0+1
- **Flutter 版本**: 3.0.0+
- **最后更新**: 2025/10/13

## 开发说明
- 使用 `useMaterial3: true` 启用 Material 3 设计
- CardTheme 配置使用 Flutter 标准 API
- 支持 Android 平台构建

## 技术支持
如有问题，请检查：
1. Flutter 环境配置是否正确
2. Android SDK 是否已安装
3. 必要的权限是否已授予

## 许可证
本项目遵循 MIT 许可证。