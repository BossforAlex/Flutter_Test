import 'package:flutter_test/flutter_test.dart';
import 'package:amapauto_listener/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app loads with the correct title
    expect(find.text('ESP32 Control'), findsOneWidget);
    
    // Verify that tabs are present
    expect(find.text('导航监听'), findsOneWidget);
    expect(find.text('蓝牙控制'), findsOneWidget);
    expect(find.text('调试工具'), findsOneWidget);
  });
}