import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'amap_listener_service.dart';
import 'navigation_data_converter.dart';
import 'bluetooth_page.dart';
import 'bluetooth_service.dart' as custom_bluetooth;
import 'broadcast_deduplicator.dart';

// ═══════════════════════════════════════════════════════════════════
// 设计语言：Automotive HUD Dashboard
// 深色主题 + 霓虹青绿强调色，模拟车载仪表盘风格
// ═══════════════════════════════════════════════════════════════════

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmapAuto 导航监听',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5A0),
          secondary: Color(0xFF00B8D4),
          surface: Color(0xFF161B22),
          onPrimary: Color(0xFF0D1117),
          onSecondary: Color(0xFF0D1117),
          onSurface: Color(0xFFE6EDF3),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF00E5A0),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF161B22),
          indicatorColor: const Color(0xFF00E5A0).withAlpha(30),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFF00E5A0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 11,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF00E5A0), size: 22);
            }
            return const IconThemeData(color: Color(0xFF8B949E), size: 22);
          }),
        ),
      ),
      home: const MainNavigationPage(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 主页面 - 底部导航
// ═══════════════════════════════════════════════════════════════════

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final custom_bluetooth.BluetoothService _bluetoothService =
      custom_bluetooth.BluetoothService();

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '导航监听',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_outlined),
            selectedIcon: Icon(Icons.bluetooth),
            label: '蓝牙控制',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
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

// ═══════════════════════════════════════════════════════════════════
// 导航监听页面 - 仪表盘风格
// ═══════════════════════════════════════════════════════════════════

class NavigationListenerPage extends StatefulWidget {
  const NavigationListenerPage({super.key});

  @override
  State<NavigationListenerPage> createState() =>
      _NavigationListenerPageState();
}

class _NavigationListenerPageState extends State<NavigationListenerPage>
    with SingleTickerProviderStateMixin {
  final AmapListenerService _amapService = AmapListenerService();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  final List<Map<String, dynamic>> _navigationData = [];
  String _currentStatus = '等待导航数据…';
  bool _isListening = false;
  int _keyType = 0;
  int _iconValue = 0;
  int _curSpeed = 0;
  int _limitSpeed = 0;
  int _remainDis = 0;

  final BroadcastDataDeduplicator _dedup = BroadcastDataDeduplicator();
  late AnimationController _pulseController;
  Map<String, dynamic>? _nativeStatus; // 原生注册状态诊断信息

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadCache().whenComplete(_startListening);
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    await _subscription?.cancel();
    _subscription = null;

    await _amapService.setActions(const [
      'AUTONAVI_STANDARD_BROADCAST_SEND',
      'AUTONAVI_STANDARD_BROADCAST_RECV',
    ]);

    // 启动监听，获取原生注册状态
    final nativeStatus = await _amapService.startListening();
    if (mounted) {
      setState(() {
        _nativeStatus = nativeStatus;
        _isListening = _amapService.isListening;
        if (nativeStatus != null) {
          final reg = nativeStatus['registered'] == true;
          _currentStatus = reg
              ? '动态接收器已注册 · API ${nativeStatus['apiLevel'] ?? '?'}'
              : '注册失败 · API ${nativeStatus['apiLevel'] ?? '?'}';
        } else {
          _currentStatus = '正在监听 AmapAuto 广播…';
        }
      });
    }

    _subscription = _amapService.navigationStream.listen((data) {
      if (!mounted) return;

      final filtered = NavigationDataConverter.filterTechnicalFields(data);
      final summary0 = NavigationDataConverter.generateSummary(filtered);
      String desc = (summary0.isNotEmpty ? summary0
              : NavigationDataConverter.convertRouteDetails(filtered))
          .trim();

      if (desc.isEmpty || desc == '暂无导航信息') {
        if (data['EXTRA_STATE'] is int) {
          desc = NavigationDataConverter.convertStatusCode(
              data['EXTRA_STATE'] as int);
        } else if (data['KEY_ACTION'] is String) {
          desc = NavigationDataConverter.convertNavigationAction(
              data['KEY_ACTION'] as String);
        } else {
          desc = '收到导航数据';
        }
      }

      if (!_dedup.accept(desc)) return;

      String statusText = '数据更新';
      if (data['EXTRA_STATE'] is int) {
        statusText = NavigationDataConverter.convertStatusCode(
            data['EXTRA_STATE'] as int);
      } else if (data['KEY_ACTION'] is String) {
        statusText = NavigationDataConverter.convertNavigationAction(
            data['KEY_ACTION'] as String);
      }

      // 提取仪表盘数据
      final kmt = _pickNum(data, ['KEY_TYPE', 'keyType', 'type']);
      final icon = _pickNum(data, ['ICON', 'icon', 'NEW_ICON', 'newIcon']);
      final spd = _pickNum(data, ['CUR_SPEED', 'curSpeed', 'speed', 'current_speed']);
      final lmt = _pickNum(data, ['LIMITED_SPEED', 'limitSpeed', 'speed_limit', 'limit_speed']);
      final dis = _pickNum(data, ['ROUTE_REMAIN_DIS', 'remainDistance', 'route_distance', 'remaining_distance']);

      setState(() {
        _isListening = _amapService.isListening;
        _currentStatus = statusText;
        if (kmt != null) _keyType = kmt.toInt();
        if (icon != null) _iconValue = icon.toInt();
        if (spd != null) _curSpeed = spd.toInt();
        if (lmt != null) _limitSpeed = lmt.toInt();
        if (dis != null) _remainDis = dis.toInt();
        _navigationData.add({
          'timestamp': DateTime.now(),
          'data': filtered,
          'description': desc,
        });
        if (_navigationData.length > 100) {
          _navigationData.removeRange(0, _navigationData.length - 100);
        }
      });
      _saveCache();
    });

    setState(() {
      _isListening = true;
      _currentStatus = '正在监听 AmapAuto 广播…';
    });
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _amapService.stopListening();
    await _subscription?.cancel();
    _subscription = null;
    setState(() {
      _isListening = false;
      _currentStatus = '监听已停止';
    });
  }

  void _clearData() async {
    setState(() {
      _navigationData.clear();
      _currentStatus = '数据已清空';
      _keyType = 0;
      _iconValue = 0;
      _curSpeed = 0;
      _limitSpeed = 0;
      _remainDis = 0;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nav_cache');
  }

  void _copyData() {
    if (_navigationData.isEmpty) return;
    final dataToCopy =
        _navigationData.map((e) => e['description'] as String).join('\n\n');
    Clipboard.setData(ClipboardData(text: dataToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('导航信息已复制到剪贴板'),
        backgroundColor: Color(0xFF00E5A0),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCacheManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildCacheSheet(context),
    );
  }

  Widget _buildCacheSheet(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              Icons.cleaning_services_outlined,
              '清空缓存数据',
              '清除所有已收集的导航记录',
              () {
                Navigator.pop(context);
                _clearData();
              },
            ),
            _buildActionTile(
              Icons.file_copy_outlined,
              '导出缓存为文本',
              '将所有数据复制到剪贴板',
              () {
                final text = _navigationData
                    .map((e) => '[${e['timestamp']}] ${e['description']}')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('缓存内容已复制'),
                    backgroundColor: Color(0xFF00E5A0),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _buildActionTile(
              _isListening ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
              _isListening ? '停止监听' : '开始监听',
              _isListening ? '停止接收导航广播' : '启动广播监听',
              () {
                Navigator.pop(context);
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5A0).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF00E5A0), size: 22),
        ),
        title: Text(title, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF484F58)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: const Color(0xFF0D1117),
      ),
    );
  }

  void _openDebugTools() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('调试工具', style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildActionTile(
                Icons.tune, '设置标准 Actions', '注册 AUTONAVI_STANDARD_BROADCAST_SEND/RECV',
                () { Navigator.pop(context); _handleSetActions(); },
              ),
              _buildActionTile(
                Icons.campaign_outlined, '发送测试广播', '验证广播通道是否正常',
                () { Navigator.pop(context); _handleSendTestBroadcast(); },
              ),
              _buildActionTile(
                Icons.visibility_outlined, '查看原始数据', '最近收到的原始广播',
                () { Navigator.pop(context); _showRawData(); },
              ),
              _buildActionTile(
                Icons.info_outline, '查看诊断信息', '原生广播注册状态',
                () { Navigator.pop(context); _showDiagnostics(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSetActions() async {
    try {
      await _amapService.setActions(const [
        'AUTONAVI_STANDARD_BROADCAST_SEND',
        'AUTONAVI_STANDARD_BROADCAST_RECV',
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标准 Actions 设置成功'), backgroundColor: Color(0xFF00E5A0), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('失败: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _handleSendTestBroadcast() async {
    try {
      await _amapService.sendTestBroadcast();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('测试广播已发送'), backgroundColor: Color(0xFF00E5A0), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showRawData() {
    if (_navigationData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无接收到的数据'), backgroundColor: Color(0xFF484F58), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('原始广播数据', style: TextStyle(color: Color(0xFF00E5A0))),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = _navigationData.length - 1;
                  i >= 0 && i >= _navigationData.length - 5;
                  i--)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('数据 #${i + 1}',
                          style: const TextStyle(color: Color(0xFF00E5A0), fontWeight: FontWeight.bold)),
                      Text('时间: ${_navigationData[i]['timestamp']}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                      Text('描述: ${_navigationData[i]['description']}',
                          style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('原始: ${_navigationData[i]['data']}',
                          style: const TextStyle(color: Color(0xFF484F58), fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: Color(0xFF00E5A0))),
          ),
        ],
      ),
    );
  }

  void _showDiagnostics() async {
    // 刷新原生状态
    final status = await _amapService.getStatus();
    if (mounted) {
      setState(() {
        _nativeStatus = status;
      });
    }

    final apiLevel = (_nativeStatus?['apiLevel'] ?? '?').toString();
    final registered = _nativeStatus?['registered'] == true;
    final pkg = _nativeStatus?['packageName'] ?? '?';
    final actions = _nativeStatus?['actions'] as List<dynamic>? ?? [];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF00E5A0), size: 20),
            SizedBox(width: 8),
            Text('原生广播诊断', style: TextStyle(color: Color(0xFF00E5A0), fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _diagRow('API Level', apiLevel),
              _diagRow('接收器状态', registered ? '已注册' : '未注册',
                  valueColor: registered ? const Color(0xFF00E5A0) : Colors.redAccent),
              _diagRow('包名', pkg.toString()),
              _diagRow('监听 Actions', actions.join(', ')),
              _diagRow('监听中', '$_isListening'),
              _diagRow('数据条数', '${_navigationData.length}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Android 14+ (API 34+) 提示',
                        style: TextStyle(color: Color(0xFF00E5A0), fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 6),
                    Text(
                      '1. 必须用 RECEIVER_EXPORTED 注册动态接收器\n'
                      '2. 静态 manifest 接收器可能无法接收自定义隐式广播\n'
                      '3. 测试广播已使用显式 Intent (setPackage) 确保送达\n'
                      '4. 如仍无数据，请检查 高德地图 是否正在导航并发送广播',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: Color(0xFF00E5A0))),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? const Color(0xFFE6EDF3),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 缓存
  // ═══════════════════════════════════════════════════════════════

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
            final ts = e['timestamp'];
            if (ts is String) {
              e['timestamp'] = DateTime.tryParse(ts) ?? DateTime.now();
            }
            return e;
          }));
      });
    } catch (_) {}
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

  num? _pickNum(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final p = num.tryParse(v);
        if (p != null) return p;
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // UI 构建
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AMAPAUTO 监听'),
        actions: [
          _buildControlButton(
            icon: _isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
            tooltip: _isListening ? '停止监听' : '开始监听',
            onPressed: _isListening ? _stopListening : _startListening,
          ),
          _buildControlButton(
            icon: Icons.delete_outline_rounded,
            tooltip: '清空数据',
            onPressed: _clearData,
          ),
          _buildControlButton(
            icon: Icons.content_copy_rounded,
            tooltip: '复制信息',
            onPressed: _copyData,
          ),
          PopupMenuButton<String>(
            iconColor: const Color(0xFF8B949E),
            color: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'debug') _openDebugTools();
              if (value == 'cache') _showCacheManager();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Color(0xFF00E5A0), size: 20),
                    SizedBox(width: 8),
                    Text('调试工具', style: TextStyle(color: Color(0xFFE6EDF3))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cache',
                child: Row(
                  children: [
                    Icon(Icons.storage, color: Color(0xFF00E5A0), size: 20),
                    SizedBox(width: 8),
                    Text('缓存管理', style: TextStyle(color: Color(0xFFE6EDF3))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _navigationData.isEmpty ? _buildEmptyState() : _buildDashboard(),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: const Color(0xFF8B949E),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 空状态
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 雷达扫描动画
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5A0).withAlpha(
                      (40 + _pulseController.value * 60).toInt(),
                    ),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5A0).withAlpha(
                        (10 + _pulseController.value * 30).toInt(),
                      ),
                      blurRadius: 30 + _pulseController.value * 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.satellite_alt,
                  size: 48,
                  color: Color(0xFF00E5A0),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            '等待导航广播',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening ? '正在监听 AUTONAVI_STANDARD_BROADCAST_SEND' : '点击右上角播放按钮开始监听',
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!_isListening)
            ElevatedButton.icon(
              onPressed: _startListening,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始监听'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5A0),
                foregroundColor: const Color(0xFF0D1117),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 仪表盘
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDashboard() {
    return Column(
      children: [
        // 仪表盘面板
        _buildInstrumentPanel(),
        // 状态栏
        _buildStatusBar(),
        // 数据列表
        Expanded(child: _buildDataList()),
      ],
    );
  }

  Widget _buildInstrumentPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2332), Color(0xFF0D1520)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF21262D), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5A0).withAlpha(8),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // 速度表盘
          Expanded(
            child: _buildSpeedGauge(),
          ),
          const SizedBox(width: 16),
          // 信息面板
          Expanded(
            child: _buildInfoPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge() {
    final isOverSpeed = _limitSpeed > 0 && _curSpeed > _limitSpeed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 转向图标
        if (_iconValue > 0)
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5A0).withAlpha(20),
              border: Border.all(color: const Color(0xFF00E5A0).withAlpha(60), width: 1.5),
            ),
            child: Icon(
              _getTurnIcon(_iconValue),
              color: const Color(0xFF00E5A0),
              size: 26,
            ),
          ),
        // 速度数值
        Text(
          '$_curSpeed',
          style: TextStyle(
            color: isOverSpeed ? Colors.redAccent : const Color(0xFF00E5A0),
            fontSize: 48,
            fontWeight: FontWeight.w200,
            height: 1.0,
            fontFamily: 'monospace',
          ),
        ),
        const Text(
          'km/h',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        // 限速
        if (_limitSpeed > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isOverSpeed
                  ? Colors.redAccent.withAlpha(30)
                  : const Color(0xFF00E5A0).withAlpha(15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOverSpeed
                    ? Colors.redAccent.withAlpha(80)
                    : const Color(0xFF00E5A0).withAlpha(40),
              ),
            ),
            child: Text(
              '限速 $_limitSpeed',
              style: TextStyle(
                color: isOverSpeed ? Colors.redAccent : const Color(0xFF00E5A0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    final turnText = _iconValue > 0
        ? NavigationDataConverter.convertTurnIcon(_iconValue)
        : '直行';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 转向文字
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5A0).withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            turnText,
            style: const TextStyle(
              color: Color(0xFF00E5A0),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 剩余距离
        _buildInfoRow(
          Icons.flag_rounded,
          '剩余距离',
          NavigationDataConverter.formatDistance(_remainDis.toDouble()),
        ),
        const SizedBox(height: 8),
        // 数据条数
        _buildInfoRow(
          Icons.history_rounded,
          '数据条数',
          '${_navigationData.length} 条',
        ),
        const SizedBox(height: 8),
        // KEY_TYPE
        _buildInfoRow(
          Icons.tag_rounded,
          'KEY_TYPE',
          _keyType > 0 ? '$_keyType' : '--',
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8B949E)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    final isActive = _isListening && _navigationData.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00E5A0).withAlpha(40)
              : const Color(0xFF30363D),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Color.lerp(
                          const Color(0xFF00E5A0),
                          const Color(0xFF00E5A0).withAlpha(60),
                          _pulseController.value,
                        )
                      : const Color(0xFF484F58),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E5A0).withAlpha(
                              (20 + _pulseController.value * 40).toInt(),
                            ),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentStatus,
              style: const TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF00E5A0).withAlpha(15)
                  : const Color(0xFF30363D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'IDLE',
              style: TextStyle(
                color: isActive ? const Color(0xFF00E5A0) : const Color(0xFF8B949E),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _navigationData.length,
      itemBuilder: (context, index) {
        final data = _navigationData[_navigationData.length - 1 - index];
        final desc = data['description'] as String;
        final ts = data['timestamp'] as DateTime;
        final isLatest = index == 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLatest
                  ? const Color(0xFF00E5A0).withAlpha(50)
                  : const Color(0xFF21262D),
              width: isLatest ? 1.2 : 0.8,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isLatest
                        ? const Color(0xFF00E5A0).withAlpha(20)
                        : const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getNavIcon(desc),
                    color: isLatest
                        ? const Color(0xFF00E5A0)
                        : const Color(0xFF8B949E),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        desc,
                        style: TextStyle(
                          color: isLatest
                              ? const Color(0xFFE6EDF3)
                              : const Color(0xFF8B949E),
                          fontSize: 13,
                          fontWeight: isLatest ? FontWeight.w500 : FontWeight.normal,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(ts),
                        style: const TextStyle(
                          color: Color(0xFF484F58),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getTurnIcon(int icon) {
    switch (icon) {
      case 2: return Icons.turn_left;
      case 3: return Icons.turn_right;
      case 4: return Icons.turn_slight_left;
      case 5: return Icons.turn_slight_right;
      case 6: return Icons.turn_sharp_left;
      case 7: return Icons.turn_sharp_right;
      case 8: return Icons.u_turn_left;
      case 9: return Icons.arrow_upward;
      case 11:
      case 12: return Icons.traffic;
      case 13: return Icons.local_gas_station;
      case 14: return Icons.toll;
      case 15: return Icons.flag_circle;
      case 16: return Icons.tunnel;
      default: return Icons.navigation;
    }
  }

  IconData _getNavIcon(String desc) {
    if (desc.contains('速度') || desc.contains('km/h')) return Icons.speed;
    if (desc.contains('左转') || desc.contains('右转') || desc.contains('掉头')) return Icons.turn_right;
    if (desc.contains('直行')) return Icons.arrow_upward;
    if (desc.contains('到达') || desc.contains('目的地')) return Icons.flag;
    if (desc.contains('服务区')) return Icons.local_gas_station;
    if (desc.contains('电子眼') || desc.contains('限速')) return Icons.camera_alt;
    if (desc.contains('环岛')) return Icons.traffic;
    if (desc.contains('隧道')) return Icons.tunnel;
    return Icons.navigation;
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _amapService.stopListening();
    _pulseController.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════
// 设置页面
// ═══════════════════════════════════════════════════════════════════

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用信息
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2332), Color(0xFF0D1520)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF21262D)),
            ),
            child: Column(
              children: [
                const Icon(Icons.explore, size: 48, color: Color(0xFF00E5A0)),
                const SizedBox(height: 12),
                const Text(
                  'AmapAuto 监听器',
                  style: TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'v3.2.0',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5A0).withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E5A0).withAlpha(30)),
                  ),
                  child: const Text(
                    'AUTONAVI_STANDARD_BROADCAST_SEND / RECV',
                    style: TextStyle(color: Color(0xFF00E5A0), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 版本信息
          _buildSection('版本信息', [
            _buildInfoTile('应用版本', '3.2.0'),
            _buildInfoTile('SDK 版本', 'Flutter 3.0+ / Android API 21+'),
            _buildInfoTile('协议版本', 'AmapAuto 标准广播协议'),
          ]),

          const SizedBox(height: 24),

          // 关于
          _buildSection('关于', [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5A0).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined, color: Color(0xFF00E5A0), size: 20),
              ),
              title: const Text('使用说明', style: TextStyle(color: Color(0xFFE6EDF3))),
              subtitle: const Text('高德地图导航监听器使用指南', style: TextStyle(color: Color(0xFF8B949E))),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('使用说明功能开发中'), backgroundColor: Color(0xFF484F58), behavior: SnackBarBehavior.floating),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFF161B22),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5A0).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.code, color: Color(0xFF00E5A0), size: 20),
              ),
              title: const Text('开源许可', style: TextStyle(color: Color(0xFFE6EDF3))),
              subtitle: const Text('查看开源组件许可信息', style: TextStyle(color: Color(0xFF8B949E))),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'AmapAuto 监听器',
                applicationVersion: '3.2.0',
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFF161B22),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00E5A0),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 14)),
          Text(value, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
        ],
      ),
    );
  }
}