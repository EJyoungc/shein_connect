import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shein_pro/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SheinProcApp boots and displays splash screen brand identity', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SheinProcApp(),
      ),
    );

    // Initial splash frame verification
    expect(find.text('SHEIN'), findsOneWidget);
    expect(find.text('PROC'), findsOneWidget);
    expect(find.text('Smart Shein Shopping & Cart Assistant • Malawi'), findsOneWidget);
  });
}
