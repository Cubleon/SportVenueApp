class AppFormatters {
  const AppFormatters._();

  static const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  static const _fullWeekdays = [
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
    'воскресенье',
  ];
  static const _months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static String weekdayShort(DateTime date) => _weekdays[date.weekday - 1];

  /// The month on its own, as a date strip labels the days under it.
  static String monthGenitive(DateTime date) => _months[date.month - 1];

  /// Roughly how long it takes to walk that far, at a plain 5 km/h. It is an
  /// estimate from the distance and nothing more — no route, no traffic — so
  /// the label that carries it says "пешком" and never promises an arrival.
  static int walkMinutes(double km) => (km / 5 * 60).round().clamp(1, 999);

  static String dateShort(DateTime date) {
    return '${weekdayShort(date)} ${date.day} ${_months[date.month - 1].substring(0, 3)}';
  }

  static String dateFull(DateTime date) {
    return '${_fullWeekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  static String money(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final left = text.length - i;
      buffer.write(text[i]);
      if (left > 1 && left % 3 == 1) {
        buffer.write(' ');
      }
    }
    return '₽${buffer.toString()}';
  }

  static String phone(String digits) {
    final onlyDigits = digits.replaceAll(RegExp(r'\D'), '');
    final local = onlyDigits.startsWith('7')
        ? onlyDigits.substring(1)
        : onlyDigits;
    final padded = local.padRight(10, '0');
    return '+7 (${padded.substring(0, 3)}) ${padded.substring(3, 6)}-${padded.substring(6, 8)}-${padded.substring(8, 10)}';
  }
}

/// Picks the Russian plural form for a count.
///
/// The form depends on the last two digits, not the last one: 21 takes the
/// same form as 1, but 11 does not.
String plural(int count, String one, String few, String many) {
  final tens = count % 100;
  if (tens >= 11 && tens <= 14) {
    return many;
  }
  return switch (count % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}

/// Sentence case for names that arrive from the API already lower-cased.
extension StringCase on String {
  String get capitalized =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}
