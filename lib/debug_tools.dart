import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 调试工具类，提供各种调试和测试功能
class AmapAutoDebugTools {
  /// 生成测试蓝牙数据
  static Map<String, dynamic> generateTestBluetoothData() {
    return {
      'type': 'test',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'device_name': 'ESP32_Test_Device',
      'signal_strength': -65,
      'battery_level': 85,
      'data_sample': {
        'navigation_status': 'active',
        'current_speed': 60.5,
        'remaining_distance': 1500,
        'estimated_time': 300
      }
    };
  }

  /// 模拟蓝牙连接测试
  static Future<void> simulateConnectionTest() async {
    // 蓝牙功能已迁移到BluetoothPage，这里保留接口兼容性
    await Future.delayed(const Duration(seconds: 2));
  }
  static const platform = MethodChannel('com.example.amapauto_listener/navigation');
  
  /// 测试数据生成器
  static Map<String, dynamic> generateTestNavigationData() {
    return {
      'action': 'AMAP_AUTO_NAVI',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'route_distance': 1500,
      'route_time': 300,
      'current_speed': 60.5,
      'next_turn': '右转',
      'next_road': '中山路',
      'latitude': 39.9042,
      'longitude': 116.4074,
      'accuracy': 10.0,
      'bearing': 90.0,
      'progress': 50,
      'destination': '天安门广场',
      'is_simulated': true,
    };
  }
  
  static Map<String, dynamic> generateTestLocationData() {
    return {
      'action': 'AMAP_AUTO_LOCATION',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'latitude': 39.9042,
      'longitude': 116.4074,
      'speed': 60.5,
      'bearing': 90.0,
      'accuracy': 10.0,
      'provider': 'gps',
      'is_simulated': true,
    };
  }
  
  /// 性能测试工具
  static Future<void> performanceTest() async {
    final stopwatch = Stopwatch()..start();
    final testData = generateTestNavigationData();
    
    // 模拟1000次数据处理
    for (int i = 0; i < 1000; i++) {
      _formatDataForTest(testData);
      // 忽略结果，只测试处理速度
    }
    
    stopwatch.stop();
    // print('性能测试完成: ${stopwatch.elapsedMilliseconds}ms');
  }
  
  static String _formatDataForTest(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('测试数据详情:');
    
    data.forEach((key, value) {
      if (key != 'timestamp' && key != 'action') {
        buffer.writeln('$key: $value');
      }
    });
    
    return buffer.toString();
  }
  
  /// 数据验证工具
  static List<String> validateNavigationData(Map<String, dynamic> data) {
    final errors = <String>[];
    
    if (data.isEmpty) {
      errors.add('数据为空');
      return errors;
    }
    
    // 检查必需字段
    if (!data.containsKey('timestamp')) {
      errors.add('缺少时间戳字段');
    }
    
    if (!data.containsKey('action')) {
      errors.add('缺少动作类型字段');
    }
    
    // 检查数据类型
    if (data.containsKey('latitude') && data['latitude'] is! double) {
      errors.add('纬度数据类型错误');
    }
    
    if (data.containsKey('longitude') && data['longitude'] is! double) {
      errors.add('经度数据类型错误');
    }
    
    if (data.containsKey('speed') && data['speed'] is! double) {
      errors.add('速度数据类型错误');
    }
    
    return errors;
  }
  
  /// 调试面板组件
  static Widget buildDebugPanel(void Function() onTestData, void Function() onPerformanceTest) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9E9E9E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '调试工具',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onTestData,
            child: const Text('发送测试数据'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onPerformanceTest,
            child: const Text('性能测试'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // 导出当前配置
              _exportConfiguration();
            },
            child: const Text('导出配置'),
          ),
        ],
      ),
    );
  }
  
  static void _exportConfiguration() {
    final config = {
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'supported_actions': [
        'AMAP_AUTO_NAVI',
        'AMAP_AUTO_NAVI_DATA', 
        'AMAP_AUTO_LOCATION',
        'AMAP_AUTO_NAVIGATION',
        'XMGD_NAVIGATOR',
        'AUTONAVI_STANDARD_BROADCAST_SEND'
      ],
      'features': {
        'real_time_listening': true,
        'data_parsing': true,
        'error_handling': true,
        'ui_updates': true,
      }
    };
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(config);
    // print('配置导出:\n$jsonString');
    
    // 复制到剪贴板
    Clipboard.setData(ClipboardData(text: jsonString));
  }
  
  /// 日志分析工具
  static void analyzeLogs(List<String> logs) {
    // final errorCount = logs.where((log) => log.contains('ERROR') || log.contains('错误')).length;
    // final warningCount = logs.where((log) => log.contains('WARNING') || log.contains('警告')).length;
    // final infoCount = logs.where((log) => log.contains('INFO') || log.contains('信息')).length;
    
    // print('''
// 日志分析结果:
// - 总日志数: ${logs.length}
// - 错误数: $errorCount
// - 警告数: $warningCount  
// - 信息数: $infoCount
// - 错误率: ${(errorCount / logs.length * 100).toStringAsFixed(1)}%
// ''');
  }
}

/// 调试页面
class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试工具'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AmapAutoDebugTools.buildDebugPanel(
              () {
                // 发送测试数据
                // final testData = AmapAutoDebugTools.generateTestNavigationData();
                // print('测试数据: $testData');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('测试数据已生成')),
                );
              },
              () {
                AmapAutoDebugTools.performanceTest();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('性能测试完成')),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              '系统信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem('Flutter版本', '3.0+'),
                    _buildInfoItem('Android API', '21+'),
                    _buildInfoItem('支持的高德版本', '9.0+'),
                    _buildInfoItem('最后更新', DateTime.now().toString()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}