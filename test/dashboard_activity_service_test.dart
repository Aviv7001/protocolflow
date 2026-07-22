import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/services/dashboard_activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dashboard export history records newest events first', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DashboardActivityService();

    await service.recordExport('First protocol', 'ProtocolFlow file');
    await service.recordExport('Second protocol', 'ProtocolFlow file');

    final records = await service.loadExports();
    expect(records.map((record) => record.label), [
      'Second protocol',
      'First protocol',
    ]);
  });
}
