import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_service.dart' as custom_bluetooth;

/// 蓝牙控制页面 - 使用flutter_blue_plus实现真实蓝牙设备交互
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final custom_bluetooth.BluetoothService _bluetoothService = custom_bluetooth.BluetoothService();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _setupBluetoothListener();
  }

  void _setupBluetoothListener() {
    _bluetoothService.deviceStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });

    _bluetoothService.scanStatusStream.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });

    _bluetoothService.connectionStatusStream.listen((device) {
      setState(() {
        _connectedDevice = device;
      });
    });
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙设备控制'),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 4.0,
        actions: _buildBluetoothActions(),
      ),
      body: _buildBluetoothContent(),
    );
  }

  List<Widget> _buildBluetoothActions() {
    return [
      IconButton(
        icon: Icon(_isScanning ? Icons.stop : Icons.search),
        onPressed: _isScanning ? _stopScan : _startScan,
        tooltip: _isScanning ? '停止扫描' : '开始扫描',
      ),
      if (_connectedDevice != null)
        IconButton(
          icon: const Icon(Icons.bluetooth_disabled),
          onPressed: _disconnectDevice,
          tooltip: '断开连接',
        ),
    ];
  }

  Widget _buildBluetoothContent() {
    return Column(
      children: [
        // 状态指示器
        Container(
          width: double.infinity,
          color: _getStatusColor(),
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getStatusIcon(), color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _getStatusText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // 设备列表
        Expanded(
          child: _devices.isEmpty ? _buildEmptyState() : _buildDeviceList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      size: 80,
                      color: Color(0xFF1E88E5),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '蓝牙设备扫描',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '扫描并连接附近的蓝牙设备',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF757575),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.search),
                label: const Text('开始扫描蓝牙设备'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isConnected = device == _connectedDevice;
        
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: Icon(
              Icons.bluetooth,
              color: isConnected ? Colors.green : const Color(0xFF1E88E5),
            ),
            title: Text(
              device.advName.isEmpty ? '未知设备' : device.advName,
              style: TextStyle(
                fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                color: isConnected ? Colors.green : Colors.black,
              ),
            ),
            subtitle: Text(
              'MAC: ${device.remoteId.str}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isConnected 
                ? const Icon(Icons.check_circle, color: Colors.green)
                : IconButton(
                    icon: const Icon(Icons.link),
                    onPressed: () => _connectToDevice(device),
                    tooltip: '连接设备',
                  ),
            onTap: () => _showDeviceDetails(device),
          ),
        );
      },
    );
  }

  Color _getStatusColor() {
    if (_connectedDevice != null) return Colors.green;
    if (_isScanning) return Colors.orange;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_connectedDevice != null) return Icons.bluetooth_connected;
    if (_isScanning) return Icons.bluetooth_searching;
    return Icons.bluetooth;
  }

  String _getStatusText() {
    if (_connectedDevice != null) return '已连接: ${_connectedDevice!.advName}';
    if (_isScanning) return '正在扫描蓝牙设备...';
    return '蓝牙未连接';
  }

  void _startScan() {
    _bluetoothService.startScan();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('开始扫描蓝牙设备'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _stopScan() {
    _bluetoothService.stopScan();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('停止扫描蓝牙设备'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _connectToDevice(BluetoothDevice device) {
    _bluetoothService.connectToDevice(device);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在连接: ${device.advName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _disconnectDevice() {
    if (_connectedDevice != null) {
      _bluetoothService.disconnectDevice();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('断开连接: ${_connectedDevice!.advName}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showDeviceDetails(BluetoothDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.advName.isEmpty ? '未知设备' : device.advName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAC地址: ${device.remoteId.str}'),
            const SizedBox(height: 8),
            Text('设备类型: ${device.platformName}'),
            const SizedBox(height: 8),
            Text('连接状态: ${device == _connectedDevice ? '已连接' : '未连接'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          if (device != _connectedDevice)
            ElevatedButton(
              onPressed: () {
                _connectToDevice(device);
                Navigator.of(context).pop();
              },
              child: const Text('连接'),
            ),
        ],
      ),
    );
  }
}