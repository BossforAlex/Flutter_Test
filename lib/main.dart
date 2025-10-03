import 'package:flutter/material.dart';

void main() {
  runApp(const AmapAutoListenerApp());
}

class AmapAutoListenerApp extends StatelessWidget {
  const AmapAutoListenerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmapAuto监听器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AmapAutoHomePage(),
    );
  }
}

class AmapAutoHomePage extends StatefulWidget {
  const AmapAutoHomePage({super.key});

  @override
  State<AmapAutoHomePage> createState() => _AmapAutoHomePageState();
}

class _AmapAutoHomePageState extends State<AmapAutoHomePage> {
  // 高德导航数据示例
  String _navStatus = '等待高德导航数据...';
  String _navInfo = '';

  // TODO: 这里可以集成您的高德导航数据接收逻辑
  // 并在接收到数据时调用 setState 更新 _navStatus 和 _navInfo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AmapAuto监听器 - 自定义版本'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '这是 AmapAuto 监听器应用',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.location_on, size: 64, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              _navStatus,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (_navInfo.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _navInfo,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
