import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5A0),
          secondary: Color(0xFF00B8D4),
          surface: Color(0xFF121820),
          error: Color(0xFFFF5252),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121820),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFFE6EDF3),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF161C24),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF21262D), width: 0.5),
          ),
        ),
      ),
      home: const MainNavigationPage(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 底部导航主框架
// ═══════════════════════════════════════════════════════════════════

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final custom_bluetooth.BluetoothService _bluetoothService = custom_bluetooth.BluetoothService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          NavigationListenerPage(),
          BluetoothPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF21262D), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: const Color(0xFF121820),
          selectedItemColor: const Color(0xFF00E5A0),
          unselectedItemColor: const Color(0xFF484F58),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded, size: 22),
              activeIcon: Icon(Icons.dashboard_rounded, size: 22),
              label: '仪表盘',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth_rounded, size: 22),
              activeIcon: Icon(Icons.bluetooth_rounded, size: 22),
              label: '蓝牙',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune, size: 22),
              activeIcon: Icon(Icons.tune, size: 22),
              label: '设置',
            ),
          ],
        ),
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
// 仪表盘页面
// ═══════════════════════════════════════════════════════════════════

class NavigationListenerPage extends StatefulWidget {
  const NavigationListenerPage({super.key});

  @override
  State<NavigationListenerPage> createState() => _NavigationListenerPageState();
}

class _NavigationListenerPageState extends State<NavigationListenerPage>
    with TickerProviderStateMixin {
  final AmapListenerService _amapService = AmapListenerService();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  // 仪表盘实时数据
  String _statusText = '就绪';
  bool _isListening = false;
  bool _hasData = false;
  int _curSpeed = 0;
  int _limitSpeed = 0;
  int _remainDis = 0;
  int _remainTime = 0;
  int _iconValue = 0;
  int _keyType = 0;
  String _curRoad = '--';
  String _nextRoad = '--';
  int _dataCount = 0;
  int _cameraDist = 0;
  int _cameraSpeed = 0;

  final List<Map<String, dynamic>> _history = [];
  final BroadcastDataDeduplicator _dedup = BroadcastDataDeduplicator();

  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _loadCache().whenComplete(_startListening);
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据监听
  // ═══════════════════════════════════════════════════════════════

  Future<void> _startListening() async {
    if (_isListening) return;
    await _subscription?.cancel();
    _subscription = null;

    await _amapService.setActions(const [
      'AUTONAVI_STANDARD_BROADCAST_SEND',
      'AUTONAVI_STANDARD_BROADCAST_RECV',
    ]);

    final status = await _amapService.startListening();
    final nativeReg = status?['registered'] == true;

    _subscription = _amapService.navigationStream.listen((data) {
      if (!mounted) return;
      _processData(data);
    });

    if (mounted) {
      setState(() {
        _isListening = _amapService.isListening;
        _statusText = nativeReg ? '监听中 · API ${status?['apiLevel'] ?? '?'}' : '注册失败';
      });
    }
  }

  void _processData(Map<String, dynamic> data) {
    final filtered = NavigationDataConverter.filterTechnicalFields(data);
    final summary = NavigationDataConverter.generateSummary(filtered);
    String desc = summary.isNotEmpty ? summary : NavigationDataConverter.convertRouteDetails(filtered);
    if (desc.isEmpty || desc == '暂无导航信息') {
      desc = _getFallbackDesc(data);
    }
    if (!_dedup.accept(desc)) return;

    // 提取仪表数据
    _curSpeed = _pickInt(data, ['CUR_SPEED', 'curSpeed', 'current_speed', 'speed']);
    _limitSpeed = _pickInt(data, ['LIMITED_SPEED', 'limitSpeed', 'speed_limit']);
    _remainDis = _pickInt(data, ['ROUTE_REMAIN_DIS', 'remainDistance', 'route_distance']);
    _remainTime = _pickInt(data, ['ROUTE_REMAIN_TIME', 'remainTime', 'route_time']);
    _iconValue = _pickInt(data, ['ICON', 'icon', 'turnIcon']);
    _keyType = _pickInt(data, ['KEY_TYPE', 'keyType', 'type']);
    _curRoad = _pickStr(data, ['CUR_ROAD_NAME', 'curRoadName', 'roadName']) ?? '--';
    _nextRoad = _pickStr(data, ['NEXT_ROAD_NAME', 'nextRoadName', 'nextRoad']) ?? '--';
    _cameraDist = _pickInt(data, ['CAMERA_DIST', 'cameraDist']);
    _cameraSpeed = _pickInt(data, ['CAMERA_SPEED', 'cameraSpeed']);

    setState(() {
      _hasData = true;
      _dataCount++;
      _isListening = _amapService.isListening;
      if (data['EXTRA_STATE'] is int) {
        _statusText = NavigationDataConverter.convertStatusCode(data['EXTRA_STATE'] as int);
      } else if (data['KEY_ACTION'] is String) {
        _statusText = NavigationDataConverter.convertNavigationAction(data['KEY_ACTION'] as String);
      } else if (desc.length < 30) {
        _statusText = desc;
      }
      _history.add({'ts': DateTime.now(), 'desc': desc, 'data': filtered});
      if (_history.length > 80) _history.removeRange(0, _history.length - 80);
    });
    _saveCache();
  }

  String _getFallbackDesc(Map<String, dynamic> d) {
    if (d['EXTRA_STATE'] is int) return NavigationDataConverter.convertStatusCode(d['EXTRA_STATE'] as int);
    if (d['KEY_ACTION'] is String) return NavigationDataConverter.convertNavigationAction(d['KEY_ACTION'] as String);
    return '收到导航数据';
  }

  Future<void> _stopListening() async {
    await _amapService.stopListening();
    await _subscription?.cancel();
    _subscription = null;
    setState(() {
      _isListening = false;
      _statusText = '已停止';
    });
  }

  void _clearData() async {
    setState(() {
      _history.clear();
      _hasData = false;
      _dataCount = 0;
      _curSpeed = 0;
      _limitSpeed = 0;
      _remainDis = 0;
      _remainTime = 0;
      _iconValue = 0;
      _statusText = '已清空';
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nav_cache');
  }

  // ═══════════════════════════════════════════════════════════════
  // 仪表盘 UI 组件
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _startListening,
          color: const Color(0xFF00E5A0),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 速度仪表盘
              SliverToBoxAdapter(child: _buildSpeedometerSection()),
              // 状态指示栏
              SliverToBoxAdapter(child: _buildStatusBar()),
              // 导航信息卡片
              SliverToBoxAdapter(child: _buildNavInfoCards()),
              // 数据统计卡片
              SliverToBoxAdapter(child: _buildMetricsRow()),
              // 历史记录
              SliverToBoxAdapter(child: _buildHistoryHeader()),
              _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0E14),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  const Color(0xFF00E5A0).withAlpha(180),
                  const Color(0xFF00E5A0).withAlpha(60),
                  _pulseCtrl.value,
                ),
                boxShadow: _isListening
                    ? [BoxShadow(color: const Color(0xFF00E5A0).withAlpha(40 + (_pulseCtrl.value * 40).toInt()), blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
            ),
          ),
          const Text('AMAPAUTO DASHBOARD', style: TextStyle(letterSpacing: 2, fontSize: 14)),
        ],
      ),
      actions: [
        _buildIconBtn(
          icon: _isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
          tooltip: _isListening ? '停止' : '开始',
          onTap: _isListening ? _stopListening : _startListening,
          isActive: _isListening,
        ),
        _buildIconBtn(
          icon: Icons.campaign_rounded,
          tooltip: '发送测试广播',
          onTap: _sendTest,
        ),
        _buildIconBtn(
          icon: Icons.delete_outline_rounded,
          tooltip: '清空数据',
          onTap: _clearData,
        ),
        PopupMenuButton<String>(
          iconColor: const Color(0xFF8B949E),
          color: const Color(0xFF161C24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            _popupItem(Icons.copy_rounded, '复制数据', 'copy'),
            _popupItem(Icons.bug_report_rounded, '查看原始数据', 'raw'),
            _popupItem(Icons.info_outline_rounded, '诊断信息', 'diag'),
            _popupItem(Icons.storage_rounded, '缓存管理', 'cache'),
          ],
          onSelected: (v) {
            switch (v) {
              case 'copy': _copyData(); break;
              case 'raw': _showRawData(); break;
              case 'diag': _showDiagnostics(); break;
              case 'cache': _showCacheManager(); break;
            }
          },
        ),
      ],
    );
  }

  Widget _buildIconBtn({required IconData icon, required String tooltip, required VoidCallback onTap, bool isActive = false}) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: isActive ? const Color(0xFF00E5A0) : const Color(0xFF8B949E),
      onPressed: onTap,
      tooltip: tooltip,
      splashRadius: 18,
    );
  }

  PopupMenuItem<String> _popupItem(IconData icon, String label, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, color: const Color(0xFF00E5A0), size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 圆形速度表
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSpeedometerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: const Color(0xFF0D1520),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1A2332)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              // 速度表
              Expanded(
                flex: 5,
                child: _buildSpeedGauge(),
              ),
              const SizedBox(width: 16),
              // 右侧信息
              Expanded(
                flex: 5,
                child: _buildQuickInfo(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedGauge() {
    final isOver = _limitSpeed > 0 && _curSpeed > _limitSpeed;
    final ratio = _limitSpeed > 0 ? (_curSpeed / _limitSpeed).clamp(0.0, 1.5) : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 转向图标
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _iconValue > 0
              ? Container(
                  key: ValueKey(_iconValue),
                  width: 44, height: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5A0), Color(0xFF00B8D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(_turnIcon(_iconValue), color: const Color(0xFF0D1520), size: 22),
                )
              : const SizedBox(width: 44, height: 44),
        ),
        // 速度数字
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: isOver ? const Color(0xFFFF6B6B) : const Color(0xFF00E5A0),
            fontSize: 56,
            fontWeight: FontWeight.w200,
            height: 1.0,
            letterSpacing: -2,
          ),
          child: Text('$_curSpeed'),
        ),
        const Text('KM/H', style: TextStyle(color: Color(0xFF484F58), fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 8),
        // 限速
        if (_limitSpeed > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isOver ? const Color(0xFFFF5252).withAlpha(20) : const Color(0xFF00E5A0).withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOver ? const Color(0xFFFF5252).withAlpha(60) : const Color(0xFF00E5A0).withAlpha(30),
              ),
            ),
            child: Text(
              'LIMIT $_limitSpeed',
              style: TextStyle(
                color: isOver ? const Color(0xFFFF6B6B) : const Color(0xFF00E5A0),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        // 进度条
        if (_limitSpeed > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio > 1.0 ? 1.0 : ratio,
              minHeight: 3,
              backgroundColor: const Color(0xFF1A2332),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? const Color(0xFFFF5252) : const Color(0xFF00E5A0),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 转向指示
        if (_iconValue > 0) _infoTile(
          Icons.turn_right_rounded,
          NavigationDataConverter.convertTurnIcon(_iconValue),
          isHighlight: true,
        ),
        // 当前道路
        if (_curRoad != '--') _infoTile(Icons.road_variant_rounded, _curRoad),
        // 剩余距离
        if (_remainDis > 0) _infoTile(
          Icons.flag_rounded,
          NavigationDataConverter.formatDistance(_remainDis.toDouble()),
        ),
        // 剩余时间
        if (_remainTime > 0) _infoTile(
          Icons.schedule_rounded,
          _formatDuration(_remainTime),
        ),
        // 电子眼
        if (_cameraDist > 0) _infoTile(
          Icons.camera_alt_rounded,
          '${_cameraDist}m${_cameraSpeed > 0 ? " · 限${_cameraSpeed}" : ""}',
          warn: true,
        ),
        // 空状态
        if (!_hasData && _curRoad == '--')
          Expanded(child: Center(
            child: Text(
              _isListening ? '等待广播…' : '点击 ▶ 开始',
              style: const TextStyle(color: Color(0xFF484F58), fontSize: 13),
            ),
          )),
      ],
    );
  }

  Widget _infoTile(IconData icon, String text, {bool isHighlight = false, bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: warn ? const Color(0xFFFFA726) : (isHighlight ? const Color(0xFF00E5A0) : const Color(0xFF484F58))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isHighlight ? const Color(0xFF00E5A0) : const Color(0xFFB0B8C4),
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 状态栏
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatusBar() {
    final colors = _isListening && _hasData
        ? const [Color(0xFF162620), Color(0xFF0D1520)]
        : const [Color(0xFF161C24), Color(0xFF0D1520)];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isListening && _hasData ? const Color(0xFF00E5A0).withAlpha(25) : const Color(0xFF21262D),
          ),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    (_isListening && _hasData) ? const Color(0xFF00E5A0) : const Color(0xFF484F58),
                    (_isListening && _hasData) ? const Color(0xFF00E5A0).withAlpha(40) : const Color(0xFF484F58),
                    _pulseCtrl.value,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _statusText,
                style: const TextStyle(color: Color(0xFFB0B8C4), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildBadge(_isListening ? 'LIVE' : 'IDLE', _isListening ? const Color(0xFF00E5A0) : const Color(0xFF484F58)),
            const SizedBox(width: 8),
            _buildBadge('KEY:$_keyType', _keyType > 0 ? const Color(0xFF00B8D4) : const Color(0xFF484F58)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 导航信息卡片
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNavInfoCards() {
    if (!_hasData && _curRoad == '--') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('NAVIGATION INFO', style: TextStyle(color: Color(0xFF484F58), fontSize: 10, letterSpacing: 2)),
          ),
          Row(
            children: [
              Expanded(child: _buildMetricCard('剩余距离', '${(_remainDis / 1000).toStringAsFixed(1)}', 'km', Icons.route_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('剩余时间', '$_remainTime', 'min', Icons.timer_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('数据', '$_dataCount', '条', Icons.data_usage_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMetricCard('当前道路', _curRoad.length > 10 ? _curRoad.substring(0, 10) : _curRoad, '', Icons.road_variant_rounded, compact: true)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('下一道路', _nextRoad.length > 10 ? _nextRoad.substring(0, 10) : _nextRoad, '', Icons.signpost_rounded, compact: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon, {bool compact = false}) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF121820),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 10 : 14),
        child: compact
            ? Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF00E5A0).withAlpha(120)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(color: Color(0xFF484F58), fontSize: 9, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(value, style: const TextStyle(color: Color(0xFFB0B8C4), fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 14, color: const Color(0xFF00E5A0).withAlpha(140)),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(color: Color(0xFF484F58), fontSize: 10, letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: value, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 24, fontWeight: FontWeight.w300, height: 1)),
                      if (unit.isNotEmpty)
                        TextSpan(text: ' $unit', style: const TextStyle(color: Color(0xFF484F58), fontSize: 12)),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 统计行
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMetricsRow() {
    if (_dataCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _miniStat('KEY', '$_keyType', _keyType > 0 ? const Color(0xFF00B8D4) : null),
          const Spacer(),
          _miniStat('ICON', '$_iconValue', _iconValue > 0 ? const Color(0xFF00E5A0) : null),
          const Spacer(),
          _miniStat('SPEED', '$_curSpeed', _curSpeed > 0 ? (_curSpeed > _limitSpeed && _limitSpeed > 0 ? const Color(0xFFFF5252) : const Color(0xFF00E5A0)) : null),
          const Spacer(),
          _miniStat('LIMIT', '$_limitSpeed', _limitSpeed > 0 ? const Color(0xFFFFA726) : null),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color? color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color ?? const Color(0xFF484F58), fontSize: 15, fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(color: Color(0xFF30363D), fontSize: 9, letterSpacing: 1)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 历史列表
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Text('EVENT LOG', style: TextStyle(color: Color(0xFF484F58), fontSize: 10, letterSpacing: 2)),
          const Spacer(),
          Text('${_history.length} 条', style: const TextStyle(color: Color(0xFF30363D), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.satellite_alt_rounded, size: 48, color: Color(0xFF1A2332)),
              SizedBox(height: 16),
              Text('等待高德地图导航广播…', style: TextStyle(color: Color(0xFF484F58), fontSize: 14)),
              SizedBox(height: 4),
              Text('AUTONAVI_STANDARD_BROADCAST_SEND', style: TextStyle(color: Color(0xFF21262D), fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final idx = _history.length - 1 - i;
          final item = _history[idx];
          final isLatest = idx == _history.length - 1;
          return _buildHistoryItem(item['desc'] as String, item['ts'] as DateTime, isLatest);
        },
        childCount: _history.length,
      ),
    );
  }

  Widget _buildHistoryItem(String desc, DateTime ts, bool isLatest) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isLatest ? const Color(0xFF00E5A0).withAlpha(5) : const Color(0xFF121820),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLatest ? const Color(0xFF00E5A0).withAlpha(20) : const Color(0xFF21262D),
          ),
        ),
        child: ListTile(
          dense: true,
          leading: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF161C24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isLatest ? const Color(0xFF00E5A0).withAlpha(40) : const Color(0xFF21262D)),
            ),
            child: Icon(
              _eventIcon(desc),
              color: isLatest ? const Color(0xFF00E5A0) : const Color(0xFF484F58),
              size: 16,
            ),
          ),
          title: Text(desc, style: TextStyle(color: isLatest ? const Color(0xFFE6EDF3) : const Color(0xFF8B949E), fontSize: 13, height: 1.3)),
          trailing: Text(
            '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Color(0xFF30363D), fontSize: 10, fontFamily: 'monospace'),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          minVerticalPadding: 8,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 工具方法
  // ═══════════════════════════════════════════════════════════════

  int _pickInt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return 0;
  }

  String? _pickStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    return '${h}h${m % 60}min';
  }

  IconData _turnIcon(int icon) {
    switch (icon) {
      case 2: return Icons.turn_left_rounded;
      case 3: return Icons.turn_right_rounded;
      case 4: return Icons.turn_slight_left_rounded;
      case 5: return Icons.turn_slight_right_rounded;
      case 6: return Icons.turn_sharp_left_rounded;
      case 7: return Icons.turn_sharp_right_rounded;
      case 8: return Icons.u_turn_left_rounded;
      case 9: return Icons.arrow_upward_rounded;
      case 11: case 12: return Icons.traffic_rounded;
      case 13: return Icons.local_gas_station_rounded;
      case 14: return Icons.toll_rounded;
      case 15: return Icons.flag_circle_rounded;
      case 16: return Icons.tunnel_rounded;
      default: return Icons.navigation_rounded;
    }
  }

  IconData _eventIcon(String desc) {
    if (desc.contains('速度') || desc.contains('km/h')) return Icons.speed_rounded;
    if (desc.contains('左转') || desc.contains('右转') || desc.contains('掉头')) return Icons.turn_right_rounded;
    if (desc.contains('直行')) return Icons.arrow_upward_rounded;
    if (desc.contains('到达') || desc.contains('目的地')) return Icons.flag_rounded;
    if (desc.contains('服务区')) return Icons.local_gas_station_rounded;
    if (desc.contains('电子眼') || desc.contains('限速')) return Icons.camera_alt_rounded;
    if (desc.contains('环岛')) return Icons.traffic_rounded;
    return Icons.navigation_rounded;
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
        _history.clear();
        _history.addAll(restored.map((e) {
          final ts = e['timestamp'];
          if (ts is String) e['ts'] = DateTime.tryParse(ts) ?? DateTime.now();
          e['desc'] = e['description']?.toString() ?? '';
          return e;
        }));
        if (_history.isNotEmpty) {
          _hasData = true;
          _dataCount = _history.length;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _history.map((e) => jsonEncode({
      'timestamp': (e['ts'] is DateTime) ? (e['ts'] as DateTime).toIso8601String() : DateTime.now().toIso8601String(),
      'description': e['desc']?.toString() ?? '',
      'data': e['data'] ?? {},
    })).toList();
    await prefs.setStringList('nav_cache', list);
  }

  // ═══════════════════════════════════════════════════════════════
  // 操作功能
  // ═══════════════════════════════════════════════════════════════

  Future<void> _sendTest() async {
    try {
      await _amapService.sendTestBroadcast();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('测试广播已发送'), backgroundColor: Color(0xFF00E5A0), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _copyData() {
    if (_history.isEmpty) return;
    final text = _history.map((e) => '[${e['ts']}] ${e['desc']}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), backgroundColor: Color(0xFF00E5A0), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
    );
  }

  void _showRawData() {
    if (_history.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121820),
        title: const Text('原始数据', style: TextStyle(color: Color(0xFF00E5A0), fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = _history.length - 1; i >= 0 && i >= _history.length - 5; i--)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF0A0E14), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF21262D))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_history[i]["ts"]}', style: const TextStyle(color: Color(0xFF484F58), fontSize: 10)),
                    Text('${_history[i]["desc"]}', style: const TextStyle(color: Color(0xFFB0B8C4), fontSize: 12)),
                    Text('${_history[i]["data"]}', style: const TextStyle(color: Color(0xFF30363D), fontSize: 10)),
                  ]),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: Color(0xFF00E5A0))))],
      ),
    );
  }

  void _showDiagnostics() async {
    final status = await _amapService.getStatus();
    final apiLevel = status?['apiLevel']?.toString() ?? '?';
    final registered = status?['registered'] == true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121820),
        title: const Row(children: [Icon(Icons.info_outline, color: Color(0xFF00E5A0), size: 18), SizedBox(width: 8), Text('诊断', style: TextStyle(color: Color(0xFF00E5A0), fontSize: 16))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _diag('API Level', apiLevel),
          _diag('接收器', registered ? '已注册' : '未注册', registered ? const Color(0xFF00E5A0) : Colors.redAccent),
          _diag('Actions', (status?['actions'] as List?)?.join(', ') ?? '--'),
          _diag('数据条数', '${_history.length}'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF0A0E14), borderRadius: BorderRadius.circular(8)),
            child: const Text('Android 14+ 需 RECEIVER_EXPORTED 注册动态接收器\n测试广播使用显式 Intent (setPackage) 确保送达', style: TextStyle(color: Color(0xFF484F58), fontSize: 11)),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: Color(0xFF00E5A0))))],
      ),
    );
  }

  Widget _diag(String label, String value, [Color? c]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
        Text(value, style: TextStyle(color: c ?? const Color(0xFFE6EDF3), fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  void _showCacheManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121820),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFF30363D), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            _cacheTile(Icons.cleaning_services_rounded, '清空数据', '清除所有收集的导航记录', () { Navigator.pop(ctx); _clearData(); }),
            _cacheTile(Icons.file_copy_rounded, '导出为文本', '复制所有数据到剪贴板', () { Navigator.pop(ctx); _copyData(); }),
            _cacheTile(_isListening ? Icons.stop_circle_rounded : Icons.play_circle_rounded, _isListening ? '停止监听' : '开始监听', _isListening ? '停止接收广播' : '启动广播监听', () { Navigator.pop(ctx); _isListening ? _stopListening() : _startListening(); }),
          ]),
        ),
      ),
    );
  }

  Widget _cacheTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: const Color(0xFF00E5A0).withAlpha(15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF00E5A0), size: 18),
      ),
      title: Text(title, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(color: Color(0xFF484F58), fontSize: 11)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: const Color(0xFF0A0E14),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _amapService.stopListening();
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
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E14),
        title: const Text('SETTINGS', style: TextStyle(letterSpacing: 2, fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用信息卡片
          Card(
            color: const Color(0xFF0D1520),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1A2332))),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.explore_rounded, size: 48, color: const Color(0xFF00E5A0).withAlpha(180)),
                const SizedBox(height: 12),
                const Text('AmapAuto 监听器', style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('v3.2.0', style: TextStyle(color: Color(0xFF484F58), fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF00E5A0).withAlpha(10), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF00E5A0).withAlpha(20))),
                  child: const Text('AUTONAVI_STANDARD_BROADCAST', style: TextStyle(color: Color(0xFF00E5A0), fontSize: 10, fontFamily: 'monospace')),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _section('VERSION', [
            _row('应用版本', '3.2.0'),
            _row('SDK', 'Flutter / Android API 21+'),
            _row('协议', 'AmapAuto 标准广播协议'),
          ]),
          const SizedBox(height: 20),
          _section('ABOUT', [
            ListTile(
              leading: _tileIcon(Icons.description_rounded),
              title: const Text('使用说明', style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 14)),
              subtitle: const Text('高德地图导航监听器使用指南', style: TextStyle(color: Color(0xFF484F58), fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF121820),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: _tileIcon(Icons.code_rounded),
              title: const Text('开源许可', style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 14)),
              subtitle: const Text('查看开源组件许可信息', style: TextStyle(color: Color(0xFF484F58), fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF121820),
              onTap: () => showLicensePage(context: context, applicationName: 'AmapAuto', applicationVersion: '3.2.0'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: const TextStyle(color: Color(0xFF00E5A0), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
      ),
      ...children,
    ]);
  }

  Widget _row(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF121820), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF21262D))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Color(0xFFB0B8C4), fontSize: 13)),
        Text(value, style: const TextStyle(color: Color(0xFF484F58), fontSize: 12)),
      ]),
    );
  }

  Widget _tileIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: const Color(0xFF00E5A0).withAlpha(12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: const Color(0xFF00E5A0).withAlpha(180), size: 18),
    );
  }
}