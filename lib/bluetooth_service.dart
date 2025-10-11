import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 蓝牙服务 - 使用flutter_blue_plus实现真实蓝牙设备交互
class BluetoothService {
  final StreamController<List<BluetoothDevice>> _deviceStreamController = 
      StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<bool> _scanStatusStreamController = 
      StreamController<bool>.broadcast();
  final StreamController<BluetoothDevice?> _connectionStatusStreamController = 
      StreamController<BluetoothDevice?>.broadcast();
  
  final List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;

  BluetoothService() {
    _setupBluetoothListeners();
  }

  /// 设备流 - 实时更新发现的设备列表
  Stream<List<BluetoothDevice>> get deviceStream => _deviceStreamController.stream;
  
  /// 扫描状态流 - 实时更新扫描状态
  Stream<bool> get scanStatusStream => _scanStatusStreamController.stream;
  
  /// 连接状态流 - 实时更新连接状态
  Stream<BluetoothDevice?> get connectionStatusStream => _connectionStatusStreamController.stream;

  /// 设置蓝牙监听器
  void _setupBluetoothListeners() {
    // 监听蓝牙适配器状态
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        // 蓝牙已开启
        _scanStatusStreamController.add(_isScanning);
      } else {
        // 蓝牙已关闭，停止扫描
        _stopScan();
        _scanStatusStreamController.add(false);
      }
    });

    // 监听设备连接状态 - 使用正确的API
    FlutterBluePlus.adapterState.listen((state) {
      // 适配器状态变化处理
      _updateConnectionStatus();
    });
  }

  /// 开始扫描蓝牙设备
  void startScan() {
    if (_isScanning) return;

    _isScanning = true;
    _scanStatusStreamController.add(true);
    _discoveredDevices.clear();
    _deviceStreamController.add([]);

    // 开始扫描，设置超时时间为10秒
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!_discoveredDevices.contains(result.device)) {
          _discoveredDevices.add(result.device);
          _deviceStreamController.add(List.from(_discoveredDevices));
        }
      }
    }, onError: (error) {
      _stopScan();
      _scanStatusStreamController.addError('扫描失败: $error');
    });

    // 开始扫描
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
    );

    // 10秒后自动停止扫描
    Timer(const Duration(seconds: 10), () {
      if (_isScanning) {
        _stopScan();
      }
    });
  }

  /// 停止扫描
  void stopScan() {
    _stopScan();
  }

  void _stopScan() {
    if (!_isScanning) return;

    _isScanning = false;
    _scanStatusStreamController.add(false);
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
  }

  /// 连接到设备
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // 如果已连接其他设备，先断开
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      // 连接到新设备
      await device.connect();
      _connectedDevice = device;
      _connectionStatusStreamController.add(device);

      // 监听设备断开连接 - 使用正确的API
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionStatusStreamController.add(null);
        }
      });

    } catch (e) {
      _connectionStatusStreamController.addError('连接失败: $e');
    }
  }

  /// 断开设备连接
  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _connectionStatusStreamController.add(null);
      } catch (e) {
        _connectionStatusStreamController.addError('断开连接失败: $e');
      }
    }
  }

  /// 更新连接状态
  void _updateConnectionStatus() {
    // 这里可以添加更复杂的连接状态逻辑
    _connectionStatusStreamController.add(_connectedDevice);
  }

  /// 获取已连接的设备
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// 获取扫描状态
  bool get isScanning => _isScanning;

  /// 获取发现的设备列表
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;

  /// 清理资源
  void dispose() {
    _stopScan();
    _scanSubscription?.cancel();
    _deviceStreamController.close();
    _scanStatusStreamController.close();
    _connectionStatusStreamController.close();
    
    // 断开所有连接
    if (_connectedDevice != null) {
      _connectedDevice!.disconnect();
    }
  }
}