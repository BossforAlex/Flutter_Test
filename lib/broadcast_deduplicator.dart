// 广播数据去重管理器（简化版）
class BroadcastDataDeduplicator {
  static final BroadcastDataDeduplicator _instance = BroadcastDataDeduplicator._internal();
  factory BroadcastDataDeduplicator() => _instance;
  BroadcastDataDeduplicator._internal();
  
  String? _lastText;
  DateTime? _lastTime;
  
  // 检查是否应该处理数据（简化逻辑）
  bool accept(String text) {
    final now = DateTime.now();
    
    // 如果是空文本，直接拒绝
    if (text.isEmpty || text == '暂无导航信息') {
      return false;
    }
    
    // 时间窗口过滤：至少间隔1秒才处理相同内容
    if (_lastText == text && _lastTime != null) {
      final timeDiff = now.difference(_lastTime!);
      if (timeDiff.inSeconds < 1) {
        return false;
      }
    }
    
    // 更新缓存
    _lastText = text;
    _lastTime = now;
    
    return true;
  }
  
  // 清空缓存
  void clear() {
    _lastText = null;
    _lastTime = null;
  }
  
  // 获取实例
  static BroadcastDataDeduplicator get instance => _instance;
}