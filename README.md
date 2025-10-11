# AmapAuto 监听器 - Flutter 应用

## 项目概述
一个用于监听和显示高德导航数据的 Flutter 应用程序，提供实时数据监控、去重过滤和滚动显示功能。

## 主要功能
- 📡 **实时数据监听**：监听高德导航、位置和广播数据
- 🔍 **智能去重**：自动过滤重复数据，减少冗余信息
- 📊 **滚动显示**：支持大量数据的流畅滚动浏览
- 📋 **数据管理**：清空数据、复制到剪贴板、清空去重缓存
- 🎨 **Material 3 设计**：现代化的用户界面设计

## 技术特性
- **Flutter Framework**：使用最新的 Material 3 设计规范
- **MethodChannel**：与原生平台通信
- **ScrollablePositionedList**：高性能滚动列表
- **智能去重算法**：基于数据类型和内容的智能过滤

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
主应用程序类，配置 Material 3 主题和路由。

### AmapAutoHomePage
主页面组件，包含：
- 数据监听状态管理
- 滚动列表显示
- 数据操作功能（清空、复制、缓存管理）

### BroadcastDataDeduplicator
智能去重管理器，防止重复数据处理。

## 数据格式
应用支持多种数据类型：
- 导航数据 (onNavigationData)
- 位置数据 (onLocationData)  
- 标准广播数据 (onStandardBroadcast)
- 未知广播数据 (onUnknownBroadcast)

## 版本信息
- **当前版本**: 1.0.0
- **Flutter 版本**: 3.0.0+
- **最后更新**: 2025/10/7

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