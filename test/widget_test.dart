import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serensync/main.dart';

void main() {
  testWidgets('app launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp()),
    );
    expect(find.byType(MyApp), findsOneWidget);
  });
}
