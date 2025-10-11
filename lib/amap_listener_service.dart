import 'dart:async';
import 'package:flutter/services.dart';

/// 高德地图导航监听服务
class AmapListenerService {
  static const platform = MethodChannel('com.example.amapauto_listener/navigation');
  
  static final AmapListenerService _instance = AmapListenerService._internal();
  factory AmapListenerService() => _instance;
  AmapListenerService._internal();
  
  final StreamController<Map<String, dynamic>> _navigationStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get navigationStream => _navigationStreamController.stream;
  
  bool _isListening = false;
  
  /// 开始监听高德地图导航数据
  Future<void> startListening() async {
    if (_isListening) return;
    
    try {
      // 设置方法调用处理器
      platform.setMethodCallHandler(_handleMethodCall);
      
      // 启动监听服务
      await platform.invokeMethod('startNavigationListener');
      
      _isListening = true;
      _navigationStreamController.add({
        'type': 'status',
        'message': '开始监听高德地图导航数据',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
      
    } catch (e) {
      _navigationStreamController.add({
        'type': 'error',
        'message': '启动监听失败: $e',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    }
  }
  
  /// 停止监听
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      await platform.invokeMethod('stopNavigationListener');
      _isListening = false;
      
      _navigationStreamController.add({
        'type': 'status',
        'message': '停止监听高德地图导航数据',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
      
    } catch (e) {
      _navigationStreamController.add({
        'type': 'error',
        'message': '停止监听失败: $e',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    }
  }
  
  /// 处理方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNavigationData':
        final data = Map<String, dynamic>.from(call.arguments);
        _navigationStreamController.add(data);
        break;
        
      case 'onLocationUpdate':
        final locationData = Map<String, dynamic>.from(call.arguments);
        _navigationStreamController.add({
          'type': 'location',
          ...locationData,
          'timestamp': DateTime.now().millisecondsSinceEpoch
        });
        break;
        
      case 'onRouteUpdate':
        final routeData = Map<String, dynamic>.from(call.arguments);
        _navigationStreamController.add({
          'type': 'route',
          ...routeData,
          'timestamp': DateTime.now().millisecondsSinceEpoch
        });
        break;
        
      default:
        break;
    }
  }
  
  /// 模拟高德地图导航数据（用于测试）
  void simulateAmapData() {
    if (!_isListening) return;
    
    final testData = {
      'type': 'navigation',
      'action': 'AMAP_AUTO_NAVI',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'route_distance': 15200.5,
      'route_time': 1860,
      'current_speed': 45.6,
      'next_turn': '右转',
      'next_road': '中山路',
      'latitude': 39.9042,
      'longitude': 116.4074,
      'progress': 65,
      'destination': '天安门广场',
      'current_road': '长安街',
      'remaining_distance': 5320.8,
      'remaining_time': 720,
      'traffic_light_count': 3,
      'service_area_distance': 15000,
      'is_navigating': true,
    };
    
    _navigationStreamController.add(testData);
  }
  
  /// 获取监听状态
  bool get isListening => _isListening;
  
  /// 清理资源
  void dispose() {
    _navigationStreamController.close();
  }
}