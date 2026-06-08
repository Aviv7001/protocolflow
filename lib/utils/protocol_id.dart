import 'dart:math';

const String _protocolIdAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
final Random _secureRandom = Random.secure();

String generateProtocolId({DateTime? date, String? initials}) {
  final now = date ?? DateTime.now();
  final yyyymmdd =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final normalizedInitials = normalizeInitials(initials);
  final suffix = List.generate(
    4,
    (_) =>
        _protocolIdAlphabet[_secureRandom.nextInt(_protocolIdAlphabet.length)],
  ).join();

  return 'PT-$yyyymmdd-$normalizedInitials-$suffix';
}

bool isProtocolId(String value) {
  return RegExp(
    r'^PT-\d{8}-(?:[A-Z]{2}-[A-Z0-9]{4}|[A-Z0-9]{4}|[A-Z0-9]{6})$',
  ).hasMatch(value);
}

String initialsFromDisplayName(String? displayName) {
  if (displayName == null || displayName.trim().isEmpty) return 'XX';

  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .map((part) => part.replaceAll(RegExp(r'[^A-Za-z]'), ''))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.length >= 2) {
    return normalizeInitials('${parts.first[0]}${parts.last[0]}');
  }

  if (parts.length == 1 && parts.single.length >= 2) {
    return normalizeInitials(parts.single.substring(0, 2));
  }

  return 'XX';
}

String normalizeInitials(String? initials) {
  final letters = (initials ?? '').toUpperCase().replaceAll(
    RegExp(r'[^A-Z]'),
    '',
  );
  if (letters.length >= 2) return letters.substring(0, 2);
  return 'XX';
}
