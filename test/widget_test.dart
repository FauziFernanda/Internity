import 'package:flutter_test/flutter_test.dart';
import 'package:sismedika_intern/main.dart';

void main() {
  testWidgets('SismedikaInternApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SismedikaInternApp());
    expect(find.byType(SismedikaInternApp), findsOneWidget);
  });
}