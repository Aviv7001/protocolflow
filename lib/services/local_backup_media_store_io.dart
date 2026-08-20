import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<List<Map<String, dynamic>>> captureLocalBackupMedia(
  Iterable<Object?> values,
) async {
  final documents = await getApplicationDocumentsDirectory();
  final temporary = await getTemporaryDirectory();
  final allowedRoots = <String>[
    await documents.resolveSymbolicLinks(),
    await temporary.resolveSymbolicLinks(),
  ];
  final candidates = <String>{};
  for (final value in values) {
    _collectStrings(value, candidates);
  }

  final files = <Map<String, dynamic>>[];
  for (final path in candidates) {
    if (path.startsWith('data:') || path.contains('://')) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    final resolved = await file.resolveSymbolicLinks();
    final isAppOwned = allowedRoots.any(
      (root) =>
          resolved == root ||
          resolved.startsWith('$root${Platform.pathSeparator}'),
    );
    if (!isAppOwned) continue;
    files.add({
      'originalPath': path,
      'name': _fileName(path),
      'content': base64Encode(await file.readAsBytes()),
    });
  }
  return files;
}

Future<Map<String, String>> restoreLocalBackupMedia(dynamic rawFiles) async {
  if (rawFiles != null && rawFiles is! List) {
    throw const FormatException('Local backup contains invalid media data.');
  }
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory('${root.path}/protocolflow_restored_media');
  if (await directory.exists()) await directory.delete(recursive: true);
  if (rawFiles == null) return const {};
  await directory.create(recursive: true);

  final restored = <String, String>{};
  for (var index = 0; index < rawFiles.length; index++) {
    final entry = rawFiles[index];
    if (entry is! Map) {
      throw const FormatException('Local backup contains invalid media data.');
    }
    final data = Map<String, dynamic>.from(entry);
    final originalPath = data['originalPath'];
    final name = data['name'];
    final content = data['content'];
    if (originalPath is! String || name is! String || content is! String) {
      throw const FormatException('Local backup contains invalid media data.');
    }
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final restoredFile = File(
      '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${index}_$safeName',
    );
    await restoredFile.writeAsBytes(base64Decode(content), flush: true);
    restored[originalPath] = restoredFile.path;
  }
  return restored;
}

Future<void> clearRestoredLocalBackupMedia() async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory('${root.path}/protocolflow_restored_media');
  if (await directory.exists()) await directory.delete(recursive: true);
}

void _collectStrings(Object? value, Set<String> output) {
  if (value is String) {
    output.add(value);
    try {
      _collectStrings(jsonDecode(value), output);
    } catch (_) {
      // Plain preference strings are expected alongside JSON payloads.
    }
  } else if (value is Iterable) {
    for (final item in value) {
      _collectStrings(item, output);
    }
  } else if (value is Map) {
    for (final item in value.values) {
      _collectStrings(item, output);
    }
  }
}

String _fileName(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}
