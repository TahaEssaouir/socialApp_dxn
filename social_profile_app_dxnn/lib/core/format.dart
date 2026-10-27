/// Formatage compact des compteurs, façon Instagram.
///
/// 999 -> 999 ; 1 000 -> 1 k ; 12 400 -> 12,4 k ; 1 200 000 -> 1,2 M.
String compactCount(int value) {
  if (value < 0) return '0';
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_decimal(value / 1000)} k';
  if (value < 1000000000) return '${_decimal(value / 1000000)} M';
  return '${_decimal(value / 1000000000)} Md';
}

String _decimal(double value) {
  if (value >= 100) return value.floor().toString();
  final double truncated = (value * 10).truncateToDouble() / 10;
  if (truncated >= 100) return truncated.floor().toString();
  final String text = truncated.toStringAsFixed(1);
  final String trimmed = text.endsWith('.0')
      ? text.substring(0, text.length - 2)
      : text;
  return trimmed.replaceAll('.', ',');
}

String formatDate(DateTime date) {
  final DateTime local = date.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

String formatDateTime(DateTime date) {
  final DateTime local = date.toLocal();
  return '${formatDate(local)} à ${_two(local.hour)}:${_two(local.minute)}';
}

String timeAgo(DateTime date, {DateTime? now}) {
  final Duration difference = (now ?? DateTime.now()).difference(date);
  if (difference.inSeconds < 60) return 'à l’instant';
  if (difference.inMinutes < 60) return 'il y a ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'il y a ${difference.inHours} h';
  if (difference.inDays < 7) return 'il y a ${difference.inDays} j';
  return formatDate(date);
}

String _two(int value) => value.toString().padLeft(2, '0');
