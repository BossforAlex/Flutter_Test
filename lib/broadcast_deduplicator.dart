// 广播数据去重管理器
class BroadcastDataDeduplicator {
  final Map<int, String> _lastDataCache = {};
  final Map<int, DateTime> _lastProcessTime = {};
  
  // 不同类型数据的最小处理间隔（毫秒）
  static const Map<int, int> _minIntervals = {
    10001: 3000,  // 导航状态数据：3秒
    60073: 1000,   // 红绿灯数据：1秒
    10019: 500,    // 状态变化数据：500毫秒
    60074: 5000,   // TMC数据：5秒
  };
  
  // 检查是否应该处理数据
  bool shouldProcess(int keyType, String data) {
    final now = DateTime.now();
    
    // 时间窗口过滤
    if (!_canProcessByTime(keyType, now)) {
      return false;
    }
    
    // 内容去重检查
    if (!_isSignificantChange(keyType, data)) {
      return false;
    }
    
    // 更新缓存
    _lastDataCache[keyType] = data;
    _lastProcessTime[keyType] = now;
    
    return true;
  }
  
  // 时间窗口过滤
  bool _canProcessByTime(int keyType, DateTime now) {
    final lastTime = _lastProcessTime[keyType];
    if (lastTime == null) return true;
    
    final minInterval = Duration(milliseconds: _minIntervals[keyType] ?? 1000);
    return now.difference(lastTime) >= minInterval;
  }
  
  // 内容变化检查
  bool _isSignificantChange(int keyType, String newData) {
    final lastData = _lastDataCache[keyType];
    if (lastData == null) return true;
    
    // 简单字符串比较
    if (lastData == newData) return false;
    
    // 智能内容比较（针对特定类型）
    switch (keyType) {
      case 10001: // 导航状态
        return _compareNavigationData(lastData, newData);
      case 60073: // 红绿灯
        return _compareTrafficLightData(lastData, newData);
      default:
        return true;
    }
  }
  
  // 导航数据关键字段比较
  bool _compareNavigationData(String oldData, String newData) {
    // 提取关键字段进行比较
    final oldKeyFields = _extractNavigationKeyFields(oldData);
    final newKeyFields = _extractNavigationKeyFields(newData);
    return oldKeyFields != newKeyFields;
  }
  
  // 红绿灯数据关键字段比较
  bool _compareTrafficLightData(String oldData, String newData) {
    // 提取红绿灯状态和倒计时
    final oldStatus = _extractTrafficLightStatus(oldData);
    final newStatus = _extractTrafficLightStatus(newData);
    return oldStatus != newStatus;
  }
  
  // 提取导航数据关键字段
  String _extractNavigationKeyFields(String data) {
    // 提取剩余距离、剩余时间、当前位置等关键信息
    final lines = data.split('\n');
    final keyFields = <String>[];
    
    for (final line in lines) {
      if (line.contains('剩余距离') || 
          line.contains('剩余时间') || 
          line.contains('当前位置') ||
          line.contains('下一路口') ||
          line.contains('导航动作')) {
        keyFields.add(line.trim());
      }
    }
    
    return keyFields.join('|');
  }
  
  // 提取红绿灯状态
  String _extractTrafficLightStatus(String data) {
    // 提取红绿灯颜色和倒计时
    final lines = data.split('\n');
    final status = <String>[];
    
    for (final line in lines) {
      if (line.contains('红绿灯') || 
          line.contains('倒计时') || 
          line.contains('颜色') ||
          line.contains('状态')) {
        status.add(line.trim());
      }
    }
    
    return status.join('|');
  }
  
  // 清空缓存
  void clearCache() {
    _lastDataCache.clear();
    _lastProcessTime.clear();
  }
  
  // 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedTypes': _lastDataCache.keys.toList(),
      'cacheSize': _lastDataCache.length,
      'lastProcessTimes': _lastProcessTime.map((key, value) => 
        MapEntry(key.toString(), value.toIso8601String())),
    };
  }
}