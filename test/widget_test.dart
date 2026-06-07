import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:amapauto_listener/main.dart';

void main() {
  testWidgets('App loads with correct title and navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that the app loads with the correct title
    expect(find.text('高德地图导航监听器'), findsOneWidget);

    // Verify that navigation tabs are present
    expect(find.text('导航监听'), findsOneWidget);
    expect(find.text('蓝牙控制'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('Settings page shows version info and app information', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Navigate to settings tab
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    // Verify settings page shows app name
    expect(find.text('AmapAuto监听器'), findsOneWidget);

    // Verify settings page shows version info (not empty placeholder)
    expect(find.text('版本信息'), findsOneWidget);
  });

  testWidgets('Navigation listener page shows empty state when no data', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // The first tab is navigation listener
    await tester.pumpAndSettle();

    // Verify empty state message
    expect(find.text('等待导航数据...'), findsOneWidget);
    expect(find.text('高德地图导航监听'), findsOneWidget);
  });
}