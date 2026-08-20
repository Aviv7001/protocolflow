import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/project.dart';
import 'package:protocolflow/services/storage_service.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:protocolflow/widgets/save_table_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save table dialog returns selected project', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final project = Project(id: 'project-1', name: 'Cell study');
    await StorageService().saveProjects([project]);
    SaveTableDetails? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showSaveTableDialog(
                  context,
                  suggestedName: 'Results',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-table-dialog')), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);

    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cell study').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Results');
    expect(result?.projectId, 'project-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('save table dialog can create and select a project', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    SaveTableDetails? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showSaveTableDialog(
                  context,
                  suggestedName: 'Plate',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Project name'),
      'New project',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Plate');
    expect(result?.projectId, isNotNull);
    final projects = await StorageService().loadProjects();
    expect(projects.single.name, 'New project');
    expect(tester.takeException(), isNull);
  });
}
