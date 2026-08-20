import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/import_service.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:protocolflow/widgets/backup_restore_preview_dialog.dart';

void main() {
  testWidgets('backup preview shows metadata and grouped contents', (
    tester,
  ) async {
    final preview = BackupRestorePreview(
      target: BackupRestoreTarget.local,
      sourceFileName: 'protocolflow_local_backup_2026-08-12_exported_AV.json',
      exportedAt: DateTime(2026, 8, 12, 14, 30),
      exportedByInitials: 'AV',
      items: const [
        BackupRestorePreviewItem(
          category: 'Protocols and history',
          title: 'Protocols Library Json',
          detail: 'protocols_library_json',
        ),
        BackupRestorePreviewItem(
          category: 'Tasks',
          title: 'Today Tasks Json',
          detail: 'today_tasks_json',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: Scaffold(body: BackupRestorePreviewDialog(preview: preview)),
      ),
    );
    await tester.pump();

    expect(find.text('Backup restore preview'), findsOneWidget);
    expect(find.text(preview.sourceFileName), findsOneWidget);
    expect(find.text('Protocols and history'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Restore and replace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
