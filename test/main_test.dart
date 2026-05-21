import 'package:flutter_test/flutter_test.dart';
import 'package:blankos/main.dart';

void main() {
  testWidgets('BlankOSApp should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const BlankOSApp());

    expect(find.text('BlankOS'), findsOneWidget);
  });
}
