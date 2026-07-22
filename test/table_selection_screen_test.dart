import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/screens/table_selection_screen.dart';

void main() {
  Future<void> pumpLabTools(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      const MaterialApp(
        home: TableSelectionScreen(standaloneMode: true, embedded: true),
      ),
    );
    await tester.pump();
  }

  testWidgets('lab tools grid adds columns on wide screens', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpLabTools(tester, const Size(1200, 800));

    final masterMix = tester.getCenter(find.text('Master Mix'));
    final staining = tester.getCenter(find.text('Staining'));
    final serialDilution = tester.getCenter(find.text('Serial Dilution'));
    expect(masterMix.dy, closeTo(staining.dy, 1));
    expect(staining.dy, closeTo(serialDilution.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lab tools grid remains compact on narrow screens', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpLabTools(tester, const Size(390, 800));

    final masterMix = tester.getCenter(find.text('Master Mix'));
    final staining = tester.getCenter(find.text('Staining'));
    final serialDilution = tester.getCenter(find.text('Serial Dilution'));
    expect(masterMix.dy, closeTo(staining.dy, 1));
    expect(serialDilution.dy, greaterThan(staining.dy));
    expect(tester.takeException(), isNull);
  });
}
