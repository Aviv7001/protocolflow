import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/models/protocol_table.dart';
import 'package:protocolflow/screens/saved_tables_screen.dart';
import 'package:protocolflow/services/storage_service.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedTables() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().saveProjects([
      Project(id: 'project-1', name: 'Cell study', colorValue: 0xFF00897B),
    ]);
    await StorageService().saveSavedTables([
      ProtocolTable(
        id: 'table-1',
        title: 'A long plate layout title that needs more than one line',
        type: TableType.plateLayout,
        projectId: 'project-1',
        createdAt: DateTime(2026, 8, 10),
      ),
      ProtocolTable(
        id: 'table-2',
        title: 'Mix setup',
        type: TableType.masterMix,
        createdAt: DateTime(2026, 8, 12),
      ),
    ]);
  }

  Widget buildScreen({String? initialProjectId}) {
    return MaterialApp(
      theme: ProtocolFlowTheme.lightTheme,
      home: SavedTablesScreen(initialProjectId: initialProjectId),
    );
  }

  testWidgets('saved table cards remain readable on a narrow screen', (
    tester,
  ) async {
    await seedTables();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saved-table-card-table-1')), findsOneWidget);
    expect(find.text('Plate layout'), findsOneWidget);
    expect(find.text('Cell study'), findsOneWidget);
    expect(find.text('Created on 2026-08-10'), findsOneWidget);
    expect(
      find.byKey(const Key('saved-table-type-icon-table-1')),
      findsOneWidget,
    );
    final badge = tester.widget<Container>(
      find.byKey(const Key('saved-table-project-badge-table-1')),
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF00897B).withValues(alpha: 0.18));
    expect(tester.takeException(), isNull);
  });

  test('newly saved tables receive a creation timestamp', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().upsertSavedTable(
      ProtocolTable(id: 'new-table', title: 'New table'),
    );

    final saved = await StorageService().loadSavedTables();
    expect(saved.single.createdAt, isNotNull);
  });

  testWidgets('saved tables search, filter by type, and sort', (tester) async {
    await seedTables();
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Saved Tables'), findsOneWidget);
    expect(find.byKey(const Key('saved-tables-create')), findsOneWidget);
    expect(
      find.byKey(const Key('saved-tables-project-filter')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('saved-tables-type-filter')), findsOneWidget);
    expect(find.byKey(const Key('saved-tables-sort')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('saved-tables-search')), 'mix');
    await tester.pump();
    expect(find.text('Mix setup'), findsOneWidget);
    expect(
      find.text('A long plate layout title that needs more than one line'),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Clear search'));
    await tester.tap(find.byKey(const Key('saved-tables-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plate layout').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-table-card-table-1')), findsOneWidget);
    expect(find.byKey(const Key('saved-table-card-table-2')), findsNothing);

    await tester.tap(find.byKey(const Key('saved-tables-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All table types'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved-tables-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date (ascending)'));
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(
            find.text(
              'A long plate layout title that needs more than one line',
            ),
          )
          .dy,
      lessThan(tester.getTopLeft(find.text('Mix setup')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('project chip reassigns a saved table', (tester) async {
    await seedTables();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cell study'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cell study'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unassigned').last);
    await tester.pumpAndSettle();

    final tables = await StorageService().loadSavedTables();
    final table = tables.singleWhere((item) => item.id == 'table-1');
    expect(table.projectId, isNull);
    expect(find.text('Unassigned'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved table grid uses desktop width without overflow', (
    tester,
  ) async {
    await seedTables();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNWidgets(2));
    expect(find.byKey(const Key('saved-table-card-table-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved tables can open with a project filter', (tester) async {
    await seedTables();
    await tester.pumpWidget(buildScreen(initialProjectId: 'project-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saved-table-card-table-1')), findsOneWidget);
    expect(find.byKey(const Key('saved-table-card-table-2')), findsNothing);
  });
}
