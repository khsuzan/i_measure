import 'package:flutter_test/flutter_test.dart';
import 'package:i_measure/main.dart';

void main() {
  testWidgets('App launches with measure screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MeasureApp());
    expect(find.byType(MeasureApp), findsOneWidget);
  });
}
