import 'package:flutter_test/flutter_test.dart';
import 'package:limit_ai/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const LimitAIApp());
    expect(find.text('multi mause'), findsWidgets);
  });
}
