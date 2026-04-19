import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lunex/app/app.dart';

void main() {
  testWidgets('Lunex home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LunexApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lunex'), findsOneWidget);
    expect(find.text('VPN Profile'), findsOneWidget);
    expect(find.text('Import Profile'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Live Logs'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Warn'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Copy Path'), findsNothing);
  });
}
