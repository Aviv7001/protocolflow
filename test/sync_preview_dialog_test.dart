import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/drive_sync_service.dart';
import 'package:protocolflow/theme/app_theme.dart';
import 'package:protocolflow/widgets/sync_preview_dialog.dart';

void main() {
  testWidgets('sync preview groups actions and applies keep decision', (
    tester,
  ) async {
    Map<String, DriveDeletionDecision>? appliedDecisions;
    const preview = DriveSyncPreview.test(
      items: [
        DriveSyncPreviewItem(
          key: 'protocol::upload',
          category: 'Protocols',
          title: 'Local protocol',
          action: DriveSyncActionType.upload,
        ),
        DriveSyncPreviewItem(
          key: 'protocol::delete',
          category: 'Protocols',
          title: 'Deleted protocol',
          action: DriveSyncActionType.delete,
          canKeep: true,
        ),
        DriveSyncPreviewItem(
          key: 'todayTask::remote',
          category: "Today's tasks",
          title: 'Remote task',
          action: DriveSyncActionType.download,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: SyncPreviewDialog(
          syncService: DriveSyncService.instance,
          promptIfNecessary: false,
          preparePreview: (_) async => preview,
          applyPreview: (_, decisions) async {
            appliedDecisions = Map.of(decisions);
            return const DriveSyncSummary(uploaded: 1, downloaded: 1);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload 1'), findsOneWidget);
    expect(find.text('Download 1'), findsOneWidget);
    expect(find.text('Delete 1'), findsOneWidget);
    expect(find.text('Deleted protocol'), findsOneWidget);

    await tester.tap(find.text('Delete everywhere'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep everywhere').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve-sync-preview')));
    await tester.pumpAndSettle();

    expect(
      appliedDecisions?['protocol::delete'],
      DriveDeletionDecision.keepEverywhere,
    );
  });

  testWidgets('sync preview shows a blocking preparation state', (
    tester,
  ) async {
    final preparation = Completer<DriveSyncPreview>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: SyncPreviewDialog(
          syncService: DriveSyncService.instance,
          promptIfNecessary: false,
          preparePreview: (_) => preparation.future,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Comparing devices...'), findsOneWidget);
    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    expect(cancel.onPressed, isNull);
  });

  testWidgets('sync preview fits a narrow mobile viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    const preview = DriveSyncPreview.test(
      items: [
        DriveSyncPreviewItem(
          key: 'protocol::delete-mobile',
          category: 'Protocols',
          title: 'Long protocol title that still needs a deletion decision',
          action: DriveSyncActionType.delete,
          canKeep: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ProtocolFlowTheme.lightTheme,
        home: SyncPreviewDialog(
          syncService: DriveSyncService.instance,
          promptIfNecessary: false,
          preparePreview: (_) async => preview,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Delete everywhere'), findsOneWidget);
    expect(find.byKey(const Key('approve-sync-preview')), findsOneWidget);
  });
}
