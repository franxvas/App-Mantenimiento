DateTime addMonths(DateTime date, int months) {
  final newYear = date.year + ((date.month - 1 + months) ~/ 12);
  final newMonth = ((date.month - 1 + months) % 12) + 1;
  final day = date.day;
  final lastDay = DateTime(newYear, newMonth + 1, 0).day;
  final newDay = day > lastDay ? lastDay : day;
  return DateTime(newYear, newMonth, newDay);
}

DateTime addMonthsDouble(DateTime date, double months) {
  final wholeMonths = months.floor();
  final fraction = months - wholeMonths;
  final baseDate = addMonths(date, wholeMonths);
  // Aproximamos la fracción del mes usando 30 días.
  final extraDays = (fraction * 30).round();
  return baseDate.add(Duration(days: extraDays));
}
