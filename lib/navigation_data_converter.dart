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
  
  /// 将路线详情JSON数据转化为自然语言描述
  static String convertRouteDetails(Map<String, dynamic> routeData) {
    final buffer = StringBuffer();
    
    // 隐藏技术性字段，突出关键导航信息
    if (routeData.containsKey('route_distance')) {
      final distance = routeData['route_distance'] as double;
      buffer.writeln('📏 总路程: ${_formatDistance(distance)}');
    }
    
    if (routeData.containsKey('route_time')) {
      final time = routeData['route_time'] as int;
      buffer.writeln('⏰ 预计时间: ${_formatTime(time)}');
    }
    
    if (routeData.containsKey('current_speed')) {
      final speed = routeData['current_speed'] as double;
      buffer.writeln('🚗 当前速度: ${speed.toStringAsFixed(1)} km/h');
    }
    
    if (routeData.containsKey('next_turn') && routeData.containsKey('next_road')) {
      buffer.writeln('🔄 下一个动作: ${routeData['next_turn']}到${routeData['next_road']}');
    }
    
    if (routeData.containsKey('progress')) {
      final progress = routeData['progress'] as int;
      buffer.writeln('📊 行程进度: $progress%');
    }
    
    if (routeData.containsKey('destination')) {
      buffer.writeln('🎯 目的地: ${routeData['destination']}');
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
  
  /// 生成自然语言摘要
  static String generateSummary(Map<String, dynamic> data) {
    final summary = StringBuffer();
    
    if (data.containsKey('current_speed')) {
      summary.write('正在以${data['current_speed']}km/h的速度');
    }
    
    if (data.containsKey('next_turn')) {
      summary.write('，准备${data['next_turn']}');
    }
    
    if (data.containsKey('next_road')) {
      summary.write('到${data['next_road']}');
    }
    
    if (data.containsKey('route_distance')) {
      summary.write('，剩余${_formatDistance(data['route_distance'])}');
    }
    
    if (data.containsKey('route_time')) {
      summary.write('，预计${_formatTime(data['route_time'])}到达');
    }
    
    return summary.toString().isEmpty ? '暂无导航信息' : summary.toString();
  }
}