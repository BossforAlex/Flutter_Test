import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'amap_listener_service.dart';
import 'navigation_data_converter.dart';
import 'bluetooth_page.dart';
import 'bluetooth_service.dart' as custom_bluetooth;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '高德地图导航监听器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final custom_bluetooth.BluetoothService _bluetoothService = custom_bluetooth.BluetoothService();

  // 页面列表 - 底部导航栏对应的页面
  final List<Widget> _pages = const [
    NavigationListenerPage(),
    BluetoothPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: '导航监听',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: '蓝牙控制',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }
}

class NavigationListenerPage extends StatefulWidget {
  const NavigationListenerPage({super.key});

  @override
  State<NavigationListenerPage> createState() => _NavigationListenerPageState();
}

class _NavigationListenerPageState extends State<NavigationListenerPage> {
  final AmapListenerService _amapService = AmapListenerService();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  final List<Map<String, dynamic>> _navigationData = [];
  String _currentStatus = '等待导航开始';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // 先加载缓存，再启动监听
    _loadCache().whenComplete(_startListening);
  }

  Future<void> _startListening() async {
    if (_isListening) return;
    await _amapService.startListening();
    _subscription = _amapService.navigationStream.listen((data) {
      if (!mounted) return;

      // 生成自然语言描述（隐藏技术字段，突出关键导航信息）
      final filtered = NavigationDataConverter.filterTechnicalFields(data);
      final summary = NavigationDataConverter.generateSummary(filtered);

      // 状态优先从 status(int) 获取，否则从 action(string) 解释
      String statusText = '数据更新';
      if (data['status'] is int) {
        statusText = NavigationDataConverter.convertStatusCode(data['status'] as int);
      } else if (data['action'] is String) {
        statusText = NavigationDataConverter.convertNavigationAction(data['action'] as String);
      }

      setState(() {
        _isListening = _amapService.isListening;
        _currentStatus = statusText;
        _navigationData.add({
          'timestamp': DateTime.now(),
          'data': filtered,
          'description': summary.isNotEmpty ? summary : NavigationDataConverter.convertRouteDetails(filtered),
        });
        // 控制长度，最多 100 条
        if (_navigationData.length > 100) {
          _navigationData.removeRange(0, _navigationData.length - 100);
        }
      });
      // 持久化
      _saveCache();
    });

    setState(() {
      _isListening = true;
      _currentStatus = '开始监听导航数据';
    });
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _amapService.stopListening();
    await _subscription?.cancel();
    _subscription = null;
    setState(() {
      _isListening = false;
      _currentStatus = '已停止监听';
    });
  }

  void _clearData() async {
    setState(() {
      _navigationData.clear();
      _currentStatus = '数据已清空';
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nav_cache');
  }

  void _copyData() {
    if (_navigationData.isNotEmpty) {
      final dataToCopy = _navigationData
          .map((e) => e['description'] as String)
          .join('\n\n');
      Clipboard.setData(ClipboardData(text: dataToCopy));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导航信息已复制到剪贴板')),
      );
    }
  }

  void _showCacheManager() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('缓存管理'),
                  subtitle: Text('管理当前收集的导航数据'),
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: const Text('清空缓存数据'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearData();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_copy),
                  title: const Text('导出缓存为文本'),
                  onTap: () {
                    final text = _navigationData
                        .map((e) => '[${e['timestamp']}] ${e['description']}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('缓存内容已复制')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(_isListening ? Icons.pause_circle : Icons.play_circle),
                  title: Text(_isListening ? '停止监听' : '开始监听'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (_isListening) {
                      await _stopListening();
                    } else {
                      await _startListening();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 缓存：加载与保存
  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('nav_cache');
    if (list == null) return;
    try {
      final restored = list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      setState(() {
        _navigationData
          ..clear()
          ..addAll(restored.map((e) {
            // timestamp 使用 ISO8601 字符串保存，这里转回 DateTime
            final ts = e['timestamp'];
            if (ts is String) {
              e['timestamp'] = DateTime.tryParse(ts) ?? DateTime.now();
            }
            return e;
          }));
      });
    } catch (_) {
      // 忽略损坏缓存
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _navigationData.map((e) {
      final map = {
        'timestamp': (e['timestamp'] is DateTime)
            ? (e['timestamp'] as DateTime).toIso8601String()
            : DateTime.now().toIso8601String(),
        'description': e['description']?.toString() ?? '',
        'data': e['data'] is Map<String, dynamic> ? e['data'] : {},
      };
      return jsonEncode(map);
    }).toList(growable: false);
    await prefs.setStringList('nav_cache', list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高德地图导航监听'),
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.pause_circle : Icons.play_circle),
            onPressed: _isListening ? _stopListening : _startListening,
            tooltip: _isListening ? '停止监听' : '开始监听',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearData,
            tooltip: '清空数据',
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: _copyData,
            tooltip: '复制信息',
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            onPressed: _showCacheManager,
            tooltip: '缓存管理',
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前状态显示
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentStatus,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 导航数据列表
          Expanded(
            child: _navigationData.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.navigation, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('等待导航数据...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _navigationData.length,
                    itemBuilder: (context, index) {
                      final data = _navigationData[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: Text(
                            data['description'] as String,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            '时间: ${data['timestamp']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _amapService.stopListening();
    super.dispose();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('缓存管理'),
            subtitle: const Text('管理应用缓存数据'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存管理功能开发中')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知设置'),
            subtitle: const Text('配置导航通知'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('通知设置功能开发中')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('使用帮助'),
            subtitle: const Text('查看应用使用说明'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('使用帮助功能开发中')),
              );
            },
          ),
        ],
      ),
    );
  }
}