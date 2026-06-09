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

  /// 启动监听，返回原生注册状态
  Future<Map<String, dynamic>?> startListening() async {
    if (_isListening) return null;

    // 先取消之前的订阅
    await _ecSub?.cancel();
    _ecSub = null;

    // 重新订阅原生事件流
    _ecSub = _ec.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _controller.add(Map<String, dynamic>.from(event));
      }
    }, onError: (e) {
      _controller.add({
        'type': 'error',
        'message': '$e',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    // 启动原生监听
    bool nativeOk = false;
    String? nativeError;
    try {
      final result = await _mc.invokeMethod('startNavigationListener');
      nativeOk = result == true || result == null;
    } catch (e) {
      nativeError = e.toString();
    }

    _isListening = nativeOk;
    if (nativeOk) {
      _controller.add({
        'type': 'status',
        'message': '动态接收器注册成功，等待高德地图广播',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      _controller.add({
        'type': 'error',
        'message': '注册失败: ${nativeError ?? "未知错误"}',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // 查询原生状态用于诊断
    Map<String, dynamic>? status;
    try {
      final s = await _mc.invokeMethod('getStatus');
      if (s is Map) status = Map<String, dynamic>.from(s);
    } catch (_) {}

    return status;
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    await _mc.invokeMethod('stopNavigationListener');
    await _ecSub?.cancel();
    _ecSub = null;

    _isListening = false;
    _controller.add({
      'type': 'status',
      'message': '停止监听高德地图导航数据',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 查询原生状态（用于诊断）
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final result = await _mc.invokeMethod('getStatus');
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (_) {}
    return null;
  }

  /// 运行时配置原生监听的 Action 列表
  Future<void> setActions(List<String> actions) async {
    await _mc.invokeMethod('setActions', actions);
  }

  /// 发送内置测试广播（直接 post + 广播双通道）
  Future<void> sendTestBroadcast() => _mc.invokeMethod('sendTestBroadcast');

  /// 发送自定义广播
  Future<void> sendBroadcast(Map<String, dynamic> data) =>
      _mc.invokeMethod('sendBroadcast', data);

  void dispose() {
    _ecSub?.cancel();
    _controller.close();
  }
}