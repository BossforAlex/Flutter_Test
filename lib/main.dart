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
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

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
            const Text(
              '等待高德导航数据...',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              '测试计数器: $_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: '测试',
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
