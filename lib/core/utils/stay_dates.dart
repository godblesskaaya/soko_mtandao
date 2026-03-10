DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime toCheckoutDateExclusive(DateTime lastNight) {
  return dateOnly(lastNight).add(const Duration(days: 1));
}

DateTime toLastNight(DateTime checkoutDateExclusive) {
  return dateOnly(checkoutDateExclusive).subtract(const Duration(days: 1));
}

int stayNightsInclusive(DateTime firstNight, DateTime lastNight) {
  final start = dateOnly(firstNight);
  final end = dateOnly(lastNight);
  if (end.isBefore(start)) return 0;
  return end.difference(start).inDays + 1;
}

String formatYmd(DateTime value) {
  return dateOnly(value).toIso8601String().substring(0, 10);
}
