import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/data/formatters.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/widgets/shared_widgets.dart';

/// Numbers, money and dates written the Russian way.
void main() {
  test('money: the sign after the number, with spaces that do not break', () {
    expect(AppFormatters.money(525), '525 ₽');
    expect(AppFormatters.money(1600), '1 600 ₽');
    expect(AppFormatters.money(12500), '12 500 ₽');
  });

  test('a decimal takes a comma', () {
    expect(AppFormatters.decimal(4.8), '4,8');
    expect(AppFormatters.decimal(3.25), '3,3');
  });

  test('a time range is joined by an en dash', () {
    final draft = BookingDraft(
      venue: MockData.venues.first,
      date: DateTime(2026, 11, 1),
      durationMinutes: 90,
      startHour: 20,
      players: 4,
      mode: PaymentMode.split,
    );
    expect(draft.timeRange, '20:00–21:30');
  });

  test('a date this year leaves the year out', () {
    final now = DateTime(2026, 10, 31);
    expect(
      AppFormatters.dateFull(DateTime(2026, 11, 1), now: now),
      'воскресенье, 1 ноября',
    );
    expect(
      AppFormatters.dateFull(DateTime(2027, 1, 2), now: now),
      'суббота, 2 января 2027',
    );
  });

  test('how long ago, the way a messenger says it', () {
    final now = DateTime(2026, 10, 31, 14, 0);
    expect(AppFormatters.ago(now, now: now), 'только что');
    expect(
      AppFormatters.ago(now.subtract(const Duration(minutes: 40)), now: now),
      '40 мин назад',
    );
    expect(
      AppFormatters.ago(DateTime(2026, 10, 31, 9, 5), now: now),
      '4 ч назад',
    );
    expect(
      AppFormatters.ago(DateTime(2026, 10, 30, 10, 41), now: now),
      'вчера в 10:41',
    );
  });

  test('a strip that crosses a month names both', () {
    expect(
      AppFormatters.monthSpan(DateTime(2026, 10, 31), DateTime(2026, 11, 13)),
      'октябрь – ноябрь',
    );
    expect(
      AppFormatters.monthSpan(DateTime(2026, 11, 1), DateTime(2026, 11, 14)),
      'ноябрь',
    );
  });

  test('a route goes to the club in Yandex Maps', () {
    final venue = MockData.venues.first;
    final link = routeLink(venue);
    expect(link.host, 'yandex.ru');
    expect(
      link.queryParameters['rtext'],
      '~${venue.latitude},${venue.longitude}',
    );
  });

  test('a calendar link carries Moscow wall-clock times', () {
    final link = googleCalendarLink(
      'Игра · Лужники',
      DateTime(2026, 11, 2, 20),
      DateTime(2026, 11, 2, 21, 30),
      'Лужники, ул. Лужники, 24',
    );
    expect(link.queryParameters['dates'], '20261102T200000/20261102T213000');
    expect(link.queryParameters['ctz'], 'Europe/Moscow');
    expect(link.queryParameters['text'], 'Игра · Лужники');
  });
}
