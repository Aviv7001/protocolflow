import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/dashboard_service.dart';
import 'package:protocolflow/services/drive_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'protocol_runs_json': '[]',
      'protocols_library_json': '[]',
      'projects_json': '[]',
      'saved_tables_json': '[]',
      'today_tasks_json': '[]',
      'history_tasks_json': '[]',
    });
  });

  test('dashboard uses actual Drive footprint category sizes', () async {
    final data = await DashboardService(
      hasDriveAccountResolver: () => true,
      driveFootprintLoader: () async => const DriveAppDataFootprint(
        bytesByCategory: {
          'Projects': 120,
          'Protocols': 340,
          'Sync metadata': 45,
        },
        fileCount: 3,
      ),
    ).load();

    expect(data.footprint.driveDataAvailable, isTrue);
    expect(data.footprint.syncBytes, 505);
    expect(
      data.footprint.segments
          .singleWhere((segment) => segment.label == 'Protocols')
          .syncBytes,
      340,
    );
    expect(
      data.footprint.segments
          .singleWhere((segment) => segment.label == 'Sync metadata')
          .syncBytes,
      45,
    );
  });

  test('Drive footprint failure does not prevent dashboard loading', () async {
    final data = await DashboardService(
      hasDriveAccountResolver: () => true,
      driveFootprintLoader: () => Future.error(StateError('offline')),
    ).load();

    expect(data.footprint.driveDataAvailable, isFalse);
    expect(data.footprint.driveError, contains('offline'));
  });
}
