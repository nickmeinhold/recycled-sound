import 'package:flutter_test/flutter_test.dart';

import 'package:fade_to_human/main.dart';

void main() {
  testWidgets('Mode selector shows all modes', (WidgetTester tester) async {
    await tester.pumpWidget(const FadeToHumanApp());

    expect(find.text('KARAOKE'), findsOneWidget);
    expect(find.text('SWISS CHEESE'), findsOneWidget);
    expect(find.text('BONES'), findsOneWidget);
    expect(find.text('PERFORMANCE'), findsOneWidget);
  });
}
