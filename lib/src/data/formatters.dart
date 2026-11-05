/// Whether clubs show stars and review counts. Off until the reviews are our
/// own: the ones there now come from catalogues whose terms forbid reuse, and
/// a club with no reviews of ours has no rating to show.
const bool kShowClubRatings = false;

/// Whether distances are measured from the reader. Until the app asks for a
/// location they are measured from the centre of Moscow, so they are not
/// shown and not filtered by.
const bool kDistanceFromReader = false;

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
  static const _monthsNominative = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  /// The months a run of days covers: «октябрь», or «октябрь – ноябрь» when
  /// it crosses into the next one. Above a strip of dates the genitive of one
  /// month («октября») named only half of it and read as a broken sentence.
  static String monthSpan(DateTime first, DateTime last) {
    final a = _monthsNominative[first.month - 1];
    final b = _monthsNominative[last.month - 1];
    return first.month == last.month ? a : '$a – $b';
  }

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

  /// A day and an hour, the way the rest of the app writes a deadline:
  /// «пт 30 окт, 18:00».
  static String moment(DateTime value) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '${dateShort(value)}, $hours:$minutes';
  }

  /// «суббота, 31 октября». The year only when it is not this one: a game
  /// next Saturday does not need «2026» to be told apart from anything.
  static String dateFull(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final base =
        '${_fullWeekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
    return date.year == today.year ? base : '$base ${date.year}';
  }

  /// How long ago, the way a messenger says it: «только что», «40 мин
  /// назад», «3 ч назад», «вчера в 10:41», then the date.
  static String ago(DateTime value, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final gap = current.difference(value);
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    if (gap.inMinutes < 1) return 'только что';
    if (gap.inMinutes < 60) return '${gap.inMinutes} мин назад';
    final today = DateTime(current.year, current.month, current.day);
    if (!value.isBefore(today)) return '${gap.inHours} ч назад';
    if (!value.isBefore(today.subtract(const Duration(days: 1)))) {
      return 'вчера в $hours:$minutes';
    }
    return moment(value);
  }

  static String money(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final left = text.length - i;
      buffer.write(text[i]);
      if (left > 1 && left % 3 == 1) {
        buffer.write(_nbsp);
      }
    }
    // The way Russian writes money: the sign after the number, and spaces a
    // line cannot break at, so «1» and «600 ₽» never land on two lines.
    return '${buffer.toString()}$_nbsp₽';
  }

  static const _nbsp = '\u00A0';

  /// A number with one decimal the Russian way: «4,8», not «4.8».
  static String decimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

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
