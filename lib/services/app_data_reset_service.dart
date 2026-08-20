import 'package:shared_preferences/shared_preferences.dart';

import 'drive_sync_service.dart';
import 'local_backup_media_store.dart';

enum AppDataResetTarget { local, drive, both }

class AppDataResetResult {
  const AppDataResetResult({required this.deletedDriveFiles});

  final int deletedDriveFiles;
}

class AppDataResetService {
  AppDataResetService({DriveSyncService? driveSyncService})
    : _driveSyncService = driveSyncService ?? DriveSyncService.instance;

  static const _signedInUserKey = 'signed_in_google_user_json';

  final DriveSyncService _driveSyncService;

  Future<AppDataResetResult> reset(AppDataResetTarget target) async {
    var deletedDriveFiles = 0;
    if (target == AppDataResetTarget.drive ||
        target == AppDataResetTarget.both) {
      deletedDriveFiles = await _driveSyncService.clearAppDataFiles();
    }
    if (target == AppDataResetTarget.local ||
        target == AppDataResetTarget.both) {
      await _clearLocalData();
    }
    return AppDataResetResult(deletedDriveFiles: deletedDriveFiles);
  }

  Future<void> _clearLocalData() async {
    await clearRestoredLocalBackupMedia();
    final prefs = await SharedPreferences.getInstance();
    final signedInUser = prefs.getString(_signedInUserKey);
    await prefs.clear();
    if (signedInUser != null && signedInUser.isNotEmpty) {
      await prefs.setString(_signedInUserKey, signedInUser);
    }
  }
}
