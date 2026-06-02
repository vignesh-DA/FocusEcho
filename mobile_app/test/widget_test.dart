import 'package:flutter_test/flutter_test.dart';

import 'package:focus_echo_ai/main.dart';

void main() {
  testWidgets('FocusEchoApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusEchoApp());

    expect(find.byType(FocusEchoApp), findsOneWidget);
  });
}
