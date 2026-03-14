import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recycled_sound/app.dart';

void main() {
  testWidgets('Home screen renders with scanner CTA', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: RecycledSoundApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan a Hearing Aid'), findsOneWidget);
    expect(find.text('Open Scanner'), findsOneWidget);
  });
}
