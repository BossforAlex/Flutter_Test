/// 导航数据转换器 - 将专业术语转换为通俗易懂的表述
class NavigationDataConverter {
  
  /// 将状态码转换为文字说明
  static String convertStatusCode(int code) {
    final statusMap = {
      0: '导航未开始',
      1: '导航进行中',
      2: '导航已暂停',
      3: '导航已结束',
      4: '路线规划中',
      5: '重新规划路线',
      6: '偏航重新规划',
      7: '到达目的地',
      8: '导航异常',
      9: '等待开始',
    };
    return statusMap[code] ?? '未知状态($code)';
  }
  
  /// 将路线详情JSON数据转化为自然语言描述（兼容多字段命名与类型）
  static String convertRouteDetails(Map<String, dynamic> routeData) {
    final buffer = StringBuffer();

    // 距离：支持 route_distance / remaining_distance / remainDistance
    final num? distanceNum = _pickNum(routeData, ['route_distance', 'remaining_distance', 'remainDistance']);
    if (distanceNum != null) {
      buffer.writeln('📏 剩余路程: ${_formatDistance(distanceNum.toDouble())}');
    }

    // 时间：支持 route_time / remaining_time / remainTime（秒）
    final num? timeNum = _pickNum(routeData, ['route_time', 'remaining_time', 'remainTime']);
    if (timeNum != null) {
      buffer.writeln('⏰ 预计时间: ${_formatTime(timeNum.toInt())}');
    }

    // 当前速度：支持 current_speed / speed
    final num? speedNum = _pickNum(routeData, ['current_speed', 'speed']);
    if (speedNum != null) {
      buffer.writeln('🚗 当前速度: ${speedNum.toStringAsFixed(1)} km/h');
    }

    // 下一步动作与道路：支持 next_turn/next_road，或 nextAction/nextRoad
    final String? nextTurn = _pickString(routeData, ['next_turn', 'nextAction']);
    final String? nextRoad = _pickString(routeData, ['next_road', 'nextRoad']);
    if ((nextTurn != null && nextTurn.isNotEmpty) || (nextRoad != null && nextRoad.isNotEmpty)) {
      final action = (nextTurn ?? '直行');
      final road = (nextRoad ?? '');
      buffer.writeln(road.isNotEmpty ? '🔄 下一个动作: $action 到 $road' : '🔄 下一个动作: $action');
    }

    // 进度：progress(0-100)
    final num? progress = _pickNum(routeData, ['progress']);
    if (progress != null) {
      buffer.writeln('📊 行程进度: ${progress.toInt()}%');
    }

    // 目的地
    final String? dest = _pickString(routeData, ['destination', 'destName']);
    if (dest != null && dest.isNotEmpty) {
      buffer.writeln('🎯 目的地: $dest');
    }

    return buffer.toString();
  }
  
  /// 格式化距离显示
  static String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}米';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}公里';
    }
  }
  
  /// 格式化时间显示
  static String _formatTime(int seconds) {
    if (seconds < 60) {
      return '$seconds秒';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes分$remainingSeconds秒';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours小时$minutes分';
    }
  }
  
  /// 转换导航动作
  static String convertNavigationAction(String action) {
    final actionMap = {
      'AMAP_AUTO_NAVI': '开始导航',
      'AMAP_AUTO_LOCATION': '位置更新',
      'AMAP_AUTO_NAVI_DATA': '导航数据',
      'AMAP_AUTO_NAVIGATION': '导航状态',
      'XMGD_NAVIGATOR': '小地图导航',
      'AUTONAVI_STANDARD_BROADCAST_SEND': '标准广播',
    };
    return actionMap[action] ?? action;
  }
  
  /// 清理技术性字段，只保留用户关心的信息
  static Map<String, dynamic> filterTechnicalFields(Map<String, dynamic> data) {
    final filteredData = Map<String, dynamic>.from(data);
    
    // 移除技术性字段
    filteredData.remove('timestamp');
    filteredData.remove('is_simulated');
    filteredData.remove('accuracy');
    filteredData.remove('bearing');
    filteredData.remove('provider');
    filteredData.remove('action');
    
    return filteredData;
  }
  
  /// 生成自然语言摘要（更健壮的字段兼容）
  static String generateSummary(Map<String, dynamic> data) {
    final s = StringBuffer();

    final num? speedNum = _pickNum(data, ['current_speed', 'speed']);
    if (speedNum != null) {
      s.write('以${speedNum.toStringAsFixed(1)}km/h');
    }

    final String? nextTurn = _pickString(data, ['next_turn', 'nextAction']);
    if (nextTurn != null && nextTurn.isNotEmpty) {
      s.write(s.isEmpty ? '准备$nextTurn' : '，准备$nextTurn');
    }

    final String? nextRoad = _pickString(data, ['next_road', 'nextRoad']);
    if (nextRoad != null && nextRoad.isNotEmpty) {
      s.write('到$nextRoad');
    }

    final num? distanceNum = _pickNum(data, ['route_distance', 'remaining_distance', 'remainDistance']);
    if (distanceNum != null) {
      s.write('，剩余${_formatDistance(distanceNum.toDouble())}');
    }

    final num? timeNum = _pickNum(data, ['route_time', 'remaining_time', 'remainTime']);
    if (timeNum != null) {
      s.write('，预计${_formatTime(timeNum.toInt())}到达');
    }

    return s.isEmpty ? '暂无导航信息' : s.toString();
  }
  /// 从多个候选键中获取数值（优先第一个存在且可解析的）
  static num? _pickNum(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final parsed = num.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// 从多个候选键中获取字符串（优先第一个非空）
  static String? _pickString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}