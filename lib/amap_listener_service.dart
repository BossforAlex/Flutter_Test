import 'dart:async';
import 'package:flutter/services.dart';

/// 高德地图导航监听服务（统一使用原生通道：amap_nav / amap_nav_stream）
class AmapListenerService {
  static const MethodChannel _mc = MethodChannel('amap_nav');
  static const EventChannel _ec = EventChannel('amap_nav_stream');

  static final AmapListenerService _instance = AmapListenerService._internal();
  factory AmapListenerService() => _instance;
  AmapListenerService._internal();

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription? _ecSub;
  bool _isListening = false;

  Stream<Map<String, dynamic>> get navigationStream => _controller.stream;
  bool get isListening => _isListening;

  Future<void> startListening() async {
    if (_isListening) return;
    // 订阅原生事件流
    _ecSub ??= _ec.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _controller.add(Map<String, dynamic>.from(event));
      }
    }, onError: (e) {
      _controller.add({'type': 'error', 'message': '$e', 'timestamp': DateTime.now().millisecondsSinceEpoch});
    });
    await _mc.invokeMethod('startNavigationListener');
    _isListening = true;
    _controller.add({'type': 'status', 'message': '开始监听高德地图导航数据', 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _mc.invokeMethod('stopNavigationListener');
    _isListening = false;
    _controller.add({'type': 'status', 'message': '停止监听高德地图导航数据', 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  // 运行时配置原生监听的 Action 列表（不需重打包）
  Future<void> setActions(List<String> actions) async {
    await _mc.invokeMethod('setActions', actions);
  }

  // 发送内置测试广播（用于环回测试）
  Future<void> sendTestBroadcast() => _mc.invokeMethod('sendTestBroadcast');

  // 发送自定义广播（按实际车机键名构造）
  Future<void> sendBroadcast(Map<String, dynamic> data) =>
      _mc.invokeMethod('sendBroadcast', data);

  void dispose() {
    _ecSub?.cancel();
    _controller.close();
  }
}