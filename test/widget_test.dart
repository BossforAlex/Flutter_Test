// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_test_new/main.dart';

void main() {
  testWidgets('AmapAuto监听器页面 smoke test', (WidgetTester tester) async {
    // 构建监听器页面
    await tester.pumpWidget(const AmapAutoListenerApp());

    // 检查页面是否包含自定义标题和图标
    expect(find.text('AmapAuto监听器 - 自定义版本'), findsOneWidget);
    expect(find.text('这是 AmapAuto 监听器应用'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.text('等待高德导航数据...'), findsOneWidget);
  });
}
