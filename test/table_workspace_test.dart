import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:protocolflow/widgets/horizontal_table_scroll.dart';
import 'package:protocolflow/widgets/table_workspace.dart';

void main() {
  Future<void> pumpManagerLayout(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: const Scaffold(
          body: ResponsiveTableManagerLayout(
            controlsKey: ValueKey('controls-column'),
            previewKey: ValueKey('preview-column'),
            controls: TableWorkspaceSection(
              title: 'Configuration',
              child: SizedBox(height: 220),
            ),
            preview: TableWorkspaceSection(
              title: 'Generated table',
              child: SizedBox(height: 320),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('table manager stacks controls and preview on portrait screens', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpManagerLayout(tester, const Size(390, 844));

    final controls = tester.getTopLeft(
      find.byKey(const ValueKey('controls-column')),
    );
    final preview = tester.getTopLeft(
      find.byKey(const ValueKey('preview-column')),
    );

    expect(preview.dx, closeTo(controls.dx, 0.1));
    expect(preview.dy, greaterThan(controls.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('table manager uses a wider preview column on desktop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpManagerLayout(tester, const Size(1400, 900));

    final controlsFinder = find.byKey(const ValueKey('controls-column'));
    final previewFinder = find.byKey(const ValueKey('preview-column'));
    final controls = tester.getTopLeft(controlsFinder);
    final preview = tester.getTopLeft(previewFinder);

    expect(preview.dx, greaterThan(controls.dx));
    expect(preview.dy, closeTo(controls.dy, 0.1));
    expect(
      tester.getSize(previewFinder).width,
      greaterThan(tester.getSize(controlsFinder).width),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('table viewer keeps long metadata inside a portrait workspace', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: const TableViewerScaffold(
          title: 'A very long table title that must remain inside the app bar',
          typeLabel: 'Serial dilution with a long association label',
          typeIcon: Icons.water_drop_outlined,
          table: TableWorkspaceSection(
            child: HorizontalTableScroll(
              minWidth: 720,
              child: SizedBox(height: 240),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('A very long table title'), findsOneWidget);
    expect(find.textContaining('Serial dilution'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
