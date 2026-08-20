import 'dart:math';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
final Random _secureRandom = Random.secure();

String generateProtocolRunId({DateTime? date}) {
  final now = date ?? DateTime.now();
  final stamp =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final suffix = List.generate(
    8,
    (_) => _alphabet[_secureRandom.nextInt(_alphabet.length)],
  ).join();
  return 'RUN-$stamp-$suffix';
}

String deterministicLegacyRunId({
  required String protocolId,
  required DateTime startedAt,
  required String source,
}) {
  final input = '$source|$protocolId|${startedAt.toUtc().toIso8601String()}';
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return 'RUN-LEGACY-${hash.toRadixString(36).toUpperCase()}';
}
