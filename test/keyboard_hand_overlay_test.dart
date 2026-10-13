import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typer_kids/widgets/keyboard_widget.dart';

void main() {
  testWidgets('SVG hand pose renders over the keyboard without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: KeyboardWidget(
              activeKey: 'a',
              keySize: 48,
              showHandOverlay: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(KeyboardWidget), findsOneWidget);
  });
}
