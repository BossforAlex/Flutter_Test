/// 导航数据转换器 - 将专业术语转换为通俗易懂的表述
/// 遵循 AmapAuto 标准广播协议字段命名
class NavigationDataConverter {
  /// 将状态码（status / EXTRA_STATE）转换为文字说明
  /// 覆盖 KEY_TYPE=10001 的导航状态及 KEY_TYPE=10019 的 EXTRA_STATE
  static String convertStatusCode(int code) {
    final statusMap = {
      // 导航状态码（status / EXTRA_STATE）
      0: '无法获取导航状态，导航未开始',
      1: '导航进行中',
      2: '导航已暂停',
      3: '导航已结束',
      4: '路线规划中',
      5: '重新规划路线',
      6: '偏航重新规划',
      7: '到达目的地',
      8: '导航异常',
      9: '等待开始',
      // EXTRA_STATE 扩展值（KEY_TYPE=10019）
      10: '路径规划完成',
      11: '路径规划失败',
      12: '导航服务未连接',
      13: 'GPS信号弱',
      14: '自适应巡航',
      15: '轻导航',
      16: '模拟导航',
    };
    return statusMap[code] ?? '未知状态($code)';
  }

  /// 将 TYPE 导航类型转换为中文描述
  static String convertNavigationType(int type) {
    const typeMap = {
      0: 'GPS导航',
      1: '模拟导航',
      2: '巡航模式',
    };
    return typeMap[type] ?? '未知类型($type)';
  }

  /// 将路线详情JSON数据转化为自然语言描述（兼容多字段命名与类型）
  /// 优先使用 AmapAuto 标准广播协议字段名，保留旧字段名作为回退
  static String convertRouteDetails(Map<String, dynamic> routeData) {
    final buffer = StringBuffer();

    // 导航类型：TYPE（0=GPS, 1=模拟, 2=巡航）
    final num? typeNum = _pickNum(routeData, ['TYPE', 'type', 'navigation_type']);
    if (typeNum != null) {
      buffer.writeln('🧭 导航类型: ${convertNavigationType(typeNum.toInt())}');
    }

    // 剩余距离：ROUTE_REMAIN_DIS（米）
    final num? distanceNum = _pickNum(
        routeData,
        ['ROUTE_REMAIN_DIS', 'remainDistance', 'route_distance',
         'remaining_distance', 'remainDis']);
    if (distanceNum != null) {
      buffer.writeln('📏 剩余路程: ${formatDistance(distanceNum.toDouble())}');
    }

    // 总距离：ROUTE_ALL_DIS
    final num? totalDistanceNum = _pickNum(
        routeData,
        ['ROUTE_ALL_DIS', 'routeAllDis', 'total_distance', 'total_route_distance']);
    if (totalDistanceNum != null) {
      buffer.writeln('📏 全程距离: ${formatDistance(totalDistanceNum.toDouble())}');
    }

    // 剩余时间：ROUTE_REMAIN_TIME（秒）
    final num? timeNum = _pickNum(
        routeData,
        ['ROUTE_REMAIN_TIME', 'remainTime', 'route_time',
         'remaining_time', 'remain_time']);
    if (timeNum != null) {
      buffer.writeln('⏰ 预计剩余时间: ${_formatTime(timeNum.toInt())}');
    }

    // 全程时间：ROUTE_ALL_TIME
    final num? totalTimeNum = _pickNum(
        routeData,
        ['ROUTE_ALL_TIME', 'routeAllTime', 'total_time', 'total_route_time']);
    if (totalTimeNum != null) {
      buffer.writeln('⏰ 全程时间: ${_formatTime(totalTimeNum.toInt())}');
    }

    // 当前段剩余距离：SEG_REMAIN_DIS
    final num? segDisNum = _pickNum(
        routeData,
        ['SEG_REMAIN_DIS', 'segRemainDis', 'seg_remain_dis']);
    if (segDisNum != null) {
      buffer.writeln('📍 当前路段剩余: ${formatDistance(segDisNum.toDouble())}');
    }

    // 当前段剩余时间：SEG_REMAIN_TIME
    final num? segTimeNum = _pickNum(
        routeData,
        ['SEG_REMAIN_TIME', 'segRemainTime', 'seg_remain_time']);
    if (segTimeNum != null) {
      buffer.writeln('📍 当前路段预计: ${_formatTime(segTimeNum.toInt())}');
    }

    // 当前速度：CUR_SPEED（km/h）
    final num? speedNum = _pickNum(
        routeData,
        ['CUR_SPEED', 'curSpeed', 'current_speed', 'speed']);
    if (speedNum != null) {
      buffer.writeln('🚗 当前速度: ${_formatSpeed(speedNum)}');
    }

    // 限速：LIMITED_SPEED（km/h）
    final num? limitSpeed = _pickNum(
        routeData,
        ['LIMITED_SPEED', 'limitSpeed', 'speed_limit', 'limit_speed',
         'limitSpeed']);
    if (limitSpeed != null) {
      buffer.writeln('⛔ 限速: $limitSpeed km/h');
    }

    // 当前道路：CUR_ROAD_NAME
    final String? curRoad = _pickString(
        routeData,
        ['CUR_ROAD_NAME', 'curRoadName', 'roadName', 'currentRoad',
         'current_road']);
    if (curRoad != null && curRoad.isNotEmpty) {
      buffer.writeln('🛣 当前道路: $curRoad');
    }

    // 下一条道路：NEXT_ROAD_NAME
    final String? nextRoad = _pickString(
        routeData,
        ['NEXT_ROAD_NAME', 'nextRoadName', 'next_road', 'nextRoad',
         'nextRoadName']);
    // 下下条道路：NEXT_NEXT_ROAD_NAME
    final String? nextNextRoad = _pickString(
        routeData,
        ['NEXT_NEXT_ROAD_NAME', 'nextNextRoadName', 'next_next_road']);

    // 转向图标：ICON / KEY_ACTION
    final int? iconValue = _parseIntFromValue(routeData, ['ICON', 'icon', 'turnIcon', 'turn_icon']);
    final String? turnActionRaw = _pickString(
        routeData,
        ['KEY_ACTION', 'keyAction', 'action', 'nextAction', 'next_turn']);
    final int? newIconValue = _parseIntFromValue(routeData, ['NEW_ICON', 'newIcon', 'new_icon']);
    final String? newIconStr = _pickString(routeData, ['NEW_ICON', 'newIcon', 'new_icon']);

    // 优先使用 ICON 数值转换，其次使用 KEY_ACTION 字符串
    final String? turnAction = iconValue != null
        ? convertTurnIcon(iconValue)
        : turnActionRaw != null
            ? convertNavigationAction(turnActionRaw)
            : null;

    final String? newTurnAction = newIconValue != null
        ? convertTurnIcon(newIconValue)
        : newIconStr != null
            ? convertNavigationAction(newIconStr)
            : null;

    if (turnAction != null && turnAction.isNotEmpty) {
      final road = (nextRoad ?? '');
      if (road.isNotEmpty) {
        buffer.writeln('🔄 下一个动作: $turnAction 到 $road');
      } else {
        buffer.writeln('🔄 下一个动作: $turnAction');
      }
    }

    if (newTurnAction != null && newTurnAction.isNotEmpty && newTurnAction != turnAction) {
      if (nextNextRoad != null && nextNextRoad.isNotEmpty) {
        buffer.writeln('↪️ 再下一个动作: $newTurnAction 到 $nextNextRoad');
      } else {
        buffer.writeln('↪️ 再下一个动作: $newTurnAction');
      }
    }

    // 下下条道路（如果没有与再下一个动作合并显示）
    if (newTurnAction == null && nextNextRoad != null && nextNextRoad.isNotEmpty) {
      buffer.writeln('↪️ 再下一条道路: $nextNextRoad');
    }

    // 车辆位置：CAR_LATITUDE / CAR_LONGITUDE
    final double? carLat = _pickDouble(routeData, ['CAR_LATITUDE', 'carLatitude', 'latitude', 'lat']);
    final double? carLng = _pickDouble(routeData, ['CAR_LONGITUDE', 'carLongitude', 'longitude', 'lng', 'lon']);
    if (carLat != null && carLng != null) {
      buffer.writeln('🌍 车辆位置: (${carLat.toStringAsFixed(6)}, ${carLng.toStringAsFixed(6)})');
    }

    // 车辆方向：CAR_DIRECTION（度）
    final num? carDir = _pickNum(routeData, ['CAR_DIRECTION', 'carDirection', 'direction', 'bearing', 'heading']);
    if (carDir != null) {
      buffer.writeln('🧭 车辆方向: ${carDir.toInt()}° (${_bearingToDirection(carDir.toInt())})');
    }

    // 服务区：SAPA_DIST, SAPA_NAME, SAPA_TYPE, SAPA_NUM
    final num? sapaDist = _pickNum(routeData, ['SAPA_DIST', 'sapaDist', 'sapa_dist']);
    final String? sapaName = _pickString(routeData, ['SAPA_NAME', 'sapaName', 'sapa_name']);
    final num? sapaNum = _pickNum(routeData, ['SAPA_NUM', 'sapaNum', 'sapa_num']);
    if (sapaDist != null) {
      final distStr = formatDistance(sapaDist.toDouble());
      final nameStr = sapaName != null && sapaName.isNotEmpty ? '($sapaName)' : '';
      final countStr = sapaNum != null ? ' [共$sapaNum个]' : '';
      buffer.writeln('🅿️ 最近服务区: $distStr$nameStr$countStr');
    } else if (sapaName != null && sapaName.isNotEmpty) {
      buffer.writeln('🅿️ 下个服务区: $sapaName');
    }

    // 电子眼：CAMERA_DIST, CAMERA_TYPE, CAMERA_SPEED
    final num? cameraDist = _pickNum(routeData, ['CAMERA_DIST', 'cameraDist', 'camera_dist']);
    final num? cameraType = _pickNum(routeData, ['CAMERA_TYPE', 'cameraType', 'camera_type']);
    final num? cameraSpeed = _pickNum(routeData, ['CAMERA_SPEED', 'cameraSpeed', 'camera_speed']);
    if (cameraDist != null) {
      final typeStr = cameraType != null ? _convertCameraType(cameraType.toInt()) : '电子眼';
      final speedStr = cameraSpeed != null ? ' 限速$cameraSpeed' : '';
      buffer.writeln('📷 $typeStr: ${formatDistance(cameraDist.toDouble())}$speedStr');
    }

    // 交通灯：TRAFFIC_LIGHT_NUM
    final num? trafficLightNum = _pickNum(
        routeData,
        ['TRAFFIC_LIGHT_NUM', 'trafficLightNum', 'traffic_light_num']);
    if (trafficLightNum != null) {
      buffer.writeln('🚦 沿途红绿灯: ${trafficLightNum.toInt()}个');
    }

    // 道路类型：ROAD_TYPE
    final num? roadType = _pickNum(routeData, ['ROAD_TYPE', 'roadType', 'road_type']);
    if (roadType != null) {
      buffer.writeln('🛤 道路类型: ${_convertRoadType(roadType.toInt())}');
    }

    // 环岛信息：ROUND_ABOUT_NUM, ROUND_ALL_NUM
    final num? roundAboutNum = _pickNum(
        routeData,
        ['ROUND_ABOUT_NUM', 'roundAboutNum', 'round_about_num']);
    final num? roundAllNum = _pickNum(
        routeData,
        ['ROUND_ALL_NUM', 'roundAllNum', 'round_all_num']);
    if (roundAboutNum != null && roundAllNum != null) {
      buffer.writeln('🔄 环岛: 第${roundAboutNum}出口/共${roundAllNum}出口');
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

    return buffer.toString().trim();
  }

  /// 将一条导航广播转化为简短自然语言摘要（更健壮的字段兼容）
  /// 优先使用 AmapAuto 标准广播协议字段名
  static String generateSummary(Map<String, dynamic> data) {
    final s = StringBuffer();

    // 首先检查状态码 / EXTRA_STATE
    final int? statusCode = _pickNum(
        data,
        ['EXTRA_STATE', 'extraState', 'status', 'nav_status',
         'navigation_status'])?.toInt();
    if (statusCode != null) {
      final statusText = convertStatusCode(statusCode);
      if (statusCode == 0 || statusCode == 9) {
        return statusText;
      }
      s.write(statusText);
    }

    // 转向图标 ICON
    final int? iconValue = _parseIntFromValue(data, ['ICON', 'icon', 'turnIcon', 'turn_icon']);
    final int? newIconValue = _parseIntFromValue(data, ['NEW_ICON', 'newIcon', 'new_icon']);
    final String? keyActionStr = _pickString(
        data,
        ['KEY_ACTION', 'keyAction', 'action', 'nextAction', 'next_turn']);

    String? nextTurn;
    if (iconValue != null) {
      nextTurn = convertTurnIcon(iconValue);
    } else if (keyActionStr != null && keyActionStr.isNotEmpty) {
      nextTurn = convertNavigationAction(keyActionStr);
    }

    if (nextTurn != null && nextTurn.isNotEmpty) {
      if (s.isNotEmpty) s.write('，');
      s.write('准备$nextTurn');
    }

    // 下一道路：NEXT_ROAD_NAME
    final String? nextRoad = _pickString(
        data,
        ['NEXT_ROAD_NAME', 'nextRoadName', 'next_road', 'nextRoad',
         'nextRoadName']);
    if (nextRoad != null && nextRoad.isNotEmpty) {
      s.write('到$nextRoad');
    }

    // 当前道路：CUR_ROAD_NAME
    final String? curRoad = _pickString(
        data,
        ['CUR_ROAD_NAME', 'curRoadName', 'roadName', 'currentRoad',
         'current_road']);

    // 当前速度：CUR_SPEED
    final num? speedNum = _pickNum(
        data,
        ['CUR_SPEED', 'curSpeed', 'current_speed', 'speed']);
    if (speedNum != null) {
      if (s.isNotEmpty) s.write('，');
      s.write('当前速度${_formatSpeed(speedNum)}');
    }

    // 限速：LIMITED_SPEED
    final num? limitSpeed = _pickNum(
        data,
        ['LIMITED_SPEED', 'limitSpeed', 'speed_limit', 'limit_speed',
         'limitSpeed']);
    if (limitSpeed != null) {
      if (s.isNotEmpty) s.write('，');
      s.write('限速$limitSpeed km/h');
    }

    // 剩余距离：ROUTE_REMAIN_DIS
    final num? distanceNum = _pickNum(
        data,
        ['ROUTE_REMAIN_DIS', 'remainDistance', 'route_distance',
         'remaining_distance', 'remainDis']);
    if (distanceNum != null) {
      if (s.isNotEmpty) s.write('，');
      s.write('剩余${formatDistance(distanceNum.toDouble())}');
    }

    // 剩余时间：ROUTE_REMAIN_TIME
    final num? timeNum = _pickNum(
        data,
        ['ROUTE_REMAIN_TIME', 'remainTime', 'route_time',
         'remaining_time', 'remain_time']);
    if (timeNum != null) {
      if (s.isNotEmpty) s.write('，');
      s.write('预计${_formatTime(timeNum.toInt())}到达');
    }

    // 电子眼：CAMERA_DIST
    final num? cameraDist = _pickNum(
        data,
        ['CAMERA_DIST', 'cameraDist', 'camera_dist']);
    if (cameraDist != null) {
      if (s.isNotEmpty) s.write('，');
      final num? cameraSpeed = _pickNum(
          data,
          ['CAMERA_SPEED', 'cameraSpeed', 'camera_speed']);
      final speedStr = cameraSpeed != null ? '限速$cameraSpeed ' : '';
      s.write('前方${formatDistance(cameraDist.toDouble())}有${speedStr}电子眼');
    }

    // 服务区：SAPA_DIST
    final num? sapaDist = _pickNum(
        data,
        ['SAPA_DIST', 'sapaDist', 'sapa_dist']);
    if (sapaDist != null) {
      if (s.isNotEmpty) s.write('，');
      s.write('服务区${formatDistance(sapaDist.toDouble())}');
    }

    // 当前道路补充（若摘要仍过短）
    if (s.isEmpty) {
      if (curRoad != null && curRoad.isNotEmpty) {
        s.write('当前道路$curRoad');
      }
    }

    final summary = s.toString().trim();
    return summary.isEmpty ? '暂无导航信息' : summary;
  }

  /// 转换导航动作（英文动作到中文、KEY_ACTION 值到中文）
  static String convertNavigationAction(String action) {
    final actionMap = {
      'AMAP_AUTO_NAVI': '开始导航',
      'AMAP_AUTO_LOCATION': '位置更新',
      'AMAP_AUTO_NAVI_DATA': '导航数据',
      'AMAP_AUTO_NAVIGATION': '导航状态',
      'XMGD_NAVIGATOR': '小地图导航',
      'AUTONAVI_STANDARD_BROADCAST_SEND': '标准广播',

      // 常见英文动作映射
      'turn-left': '左转',
      'turn-right': '右转',
      'straight': '直行',
      'u-turn': '掉头',
      'arrived': '到达目的地',
      'keep-left': '靠左',
      'keep-right': '靠右',
      'merge': '并入主路',
      'roundabout': '进入环岛',

      // 高德地图常见动作
      'ACTION_NAVIGATE': '开始导航',
      'ACTION_LOCATION': '位置更新',
      'ACTION_NAVI_DATA': '导航数据',
      'ACTION_NAVIGATION': '导航状态',

      // ICON 数值的字符串回退映射
      '0': '默认',
      '1': '自车点',
      '2': '左转',
      '3': '右转',
      '4': '左前方',
      '5': '右前方',
      '6': '左后方',
      '7': '右后方',
      '8': '左转掉头',
      '9': '直行',
      '10': '到达途经点',
      '11': '进入环岛',
      '12': '驶出环岛',
      '13': '到达服务区',
      '14': '到达收费站',
      '15': '到达目的地',
      '16': '进入隧道',
      '17': '进入匝道',
      '18': '进入高架',
      '19': '进入辅路',
      '20': '进入主路',
    };
    return actionMap[action] ?? action;
  }

  /// 将 AmapAuto 标准广播 ICON 值转换为中文描述
  /// ICON 为导航转向图标编号，取值范围 0-20（基于高德协议）
  static String convertTurnIcon(int icon) {
    const iconMap = <int, String>{
      0: '默认',
      1: '自车点',
      2: '左转',
      3: '右转',
      4: '左前方',
      5: '右前方',
      6: '左后方',
      7: '右后方',
      8: '左转掉头',
      9: '直行',
      10: '到达途经点',
      11: '进入环岛',
      12: '驶出环岛',
      13: '到达服务区',
      14: '到达收费站',
      15: '到达目的地',
      16: '进入隧道',
      17: '进入匝道',
      18: '进入高架',
      19: '进入辅路',
      20: '进入主路',
    };
    return iconMap[icon] ?? '未知转向($icon)';
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

  // ═══════════════════════════════════════════════════════════════════
  // 私有辅助方法
  // ═══════════════════════════════════════════════════════════════════

  /// 从多个候选键中获取数值（优先第一个存在且可解析的，支持 num 和 String）
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

  /// 从多个候选键中获取 int 值（主要用于 ICON 等整数字段，ICON 可能以 num 或 String 存储）
  static int? _parseIntFromValue(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// 从多个候选键中获取 double（用于经纬度等浮点字段）
  static double? _pickDouble(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
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

  static String _formatSpeed(num n) {
    final d = n.toDouble();
    final decimalPlaces = d == d.roundToDouble() ? 0 : 1;
    return '${d.toStringAsFixed(decimalPlaces)} km/h';
  }

  // 距离格式化：<1000 米按米显示，否则按公里保留1位小数
  static String formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}米';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}公里';
    }
  }

  // 时间格式化：秒 -> x小时y分 或 x分y秒 或 x秒
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

  /// 将方向角度转换为中文方位描述
  static String _bearingToDirection(int degrees) {
    final dirs = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    final index = ((degrees + 22.5) % 360 / 45).floor();
    return dirs[index % 8];
  }

  /// 将 ROAD_TYPE 转换为中文描述
  static String _convertRoadType(int type) {
    const roadTypeMap = {
      0: '普通道路',
      1: '高速/城市快速路',
      2: '国道',
      3: '省道',
      4: '县道',
      5: '乡道',
      6: '村镇道路',
      7: '其他道路',
      8: '非引导道路',
      9: '九级道路',
      10: '轮渡',
      11: '行人道路',
    };
    return roadTypeMap[type] ?? '未知道路($type)';
  }

  /// 将 CAMERA_TYPE 转换为中文描述
  static String _convertCameraType(int type) {
    const cameraTypeMap = {
      0: '电子眼',
      1: '监控摄像头',
      2: '测速电子眼',
      3: '闯红灯电子眼',
      4: '公交车道电子眼',
      5: '应急车道电子眼',
      6: '区间测速',
      7: '移动测速',
      8: '匝道测速',
    };
    return cameraTypeMap[type] ?? '电子眼($type)';
  }
}