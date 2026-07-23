String formatDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
}

String formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${formatDate(value)} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
