import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/screens/club_dashboard_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';
import 'package:sport_venue_app/src/widgets/shared_widgets.dart';

import 'support/club_dashboard_fixture.dart';

void main() {
  late ClubDashboardFixture fixture;
  setUp(() => fixture = ClubDashboardFixture());
  tearDown(() => fixture.client.close());

  testWidgets('first club requires name, address and a point on the map', (
    tester,
  ) async {
    fixture = ClubDashboardFixture(empty: true);
    await _pump(tester, fixture);
    await _tap(tester, find.byKey(const ValueKey('create-first-club')));
    await _tap(tester, find.byKey(const ValueKey('save-managed-club')));
    expect(find.text('Заполните это поле'), findsNWidgets(2));
    expect(find.text('Отметьте расположение клуба на карте.'), findsOneWidget);
    expect(
      fixture.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );
  });

  testWidgets('first location reuses the name entered for the club account', (
    tester,
  ) async {
    fixture = ClubDashboardFixture(empty: true);
    await _pump(tester, fixture, accountClubName: 'Спортклуб Арена');
    await _tap(tester, find.byKey(const ValueKey('create-first-club')));
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('club-name-field')),
    );
    expect(field.controller!.text, 'Спортклуб Арена');
  });

  testWidgets(
    'club edit preserves location, trims data and prevents double save',
    (tester) async {
      await _pump(tester, fixture);
      await _tap(tester, find.byTooltip('Редактировать клуб'));
      await tester.enterText(
        find.byKey(const ValueKey('club-name-field')),
        '  Новый клуб  ',
      );
      final gate = Completer<void>();
      fixture.beforeSave = () => gate.future;
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-managed-club')),
      );
      await tester.tap(find.byKey(const ValueKey('save-managed-club')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-managed-club')));
      await tester.pump();
      final updates = fixture.requests.where(
        (request) => request.method == 'PATCH',
      );
      expect(updates.length, 1);
      final body = jsonDecode(updates.single.body) as Map<String, dynamic>;
      expect(body['name'], 'Новый клуб');
      expect(body['geo_lat'], 55.715);
      expect(body['geo_lng'], 37.555);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Новый клуб'), findsOneWidget);
      expect(find.byKey(const ValueKey('save-managed-club')), findsNothing);
    },
  );

  testWidgets('venue validates sports, price and capacity before publishing', (
    tester,
  ) async {
    await _pump(tester, fixture);
    await _tap(tester, find.byKey(const ValueKey('create-managed-venue')));
    await _tap(tester, find.byKey(const ValueKey('save-managed-venue')));
    expect(find.text('Выберите хотя бы один вид спорта.'), findsOneWidget);
    expect(
      fixture.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );
    await _enter(tester, 'managed-venue-name', 'Футбольное поле');
    await _tap(tester, find.widgetWithText(FilterChip, 'Футбол'));
    await _enter(tester, 'managed-venue-price', '3000');
    await _enter(tester, 'managed-venue-capacity', '31');
    await _tap(tester, find.byKey(const ValueKey('save-managed-venue')));
    expect(find.text('Не больше 30'), findsOneWidget);
    await _enter(tester, 'managed-venue-capacity', '22');
    await _tap(tester, find.byKey(const ValueKey('save-managed-venue')));
    final request = fixture.requests.singleWhere(
      (request) => request.method == 'POST',
    );
    expect(request.url.path, '/api/v1/club/clubs/club-owned/venues');
    expect(jsonDecode(request.body), {
      'name': 'Футбольное поле',
      'description': '',
      'sport_ids': ['football'],
      'base_price_per_hour': 3000,
      'capacity_min': 1,
      'capacity_max': 22,
    });
    expect(
      find.byKey(const ValueKey('managed-venue-court-new')),
      findsOneWidget,
    );
  });

  testWidgets('availability converts Moscow time to UTC and allows retry', (
    tester,
  ) async {
    await _pump(tester, fixture);
    await _tap(tester, find.text('Расписание и свободное время'));
    await _tap(tester, find.byKey(const ValueKey('publish-availability')));
    fixture.saveStatus = 409;
    await _tap(tester, find.byKey(const ValueKey('save-availability')));
    expect(
      find.text(
        'Это время пересекается с уже опубликованным промежутком. Выберите другое время.',
      ),
      findsOneWidget,
    );
    final request = fixture.requests.lastWhere(
      (request) => request.method == 'POST',
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final start = DateTime.parse(body['starts_at'] as String);
    final end = DateTime.parse(body['ends_at'] as String);
    expect(start.isUtc, isTrue);
    expect(start.hour, 6); // 09:00 Moscow.
    expect(end.hour, 19); // 22:00 Moscow.
    expect(end.difference(start), const Duration(hours: 13));
    fixture.saveStatus = 200;
    await _tap(tester, find.byKey(const ValueKey('save-availability')));
    expect(
      find.byKey(const ValueKey('availability-window-new')),
      findsOneWidget,
    );
    expect(find.text('09:00 — 22:00'), findsOneWidget);
  });

  testWidgets('availability shorter than a booking cannot be published', (
    tester,
  ) async {
    await _pump(tester, fixture);
    await _tap(tester, find.text('Расписание и свободное время'));
    await _tap(tester, find.byKey(const ValueKey('publish-availability')));
    await _tap(tester, find.byKey(const ValueKey('availability-end')));
    await tester.scrollUntilVisible(
      find.text('09:30'),
      -300,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 20,
    );
    await _tap(tester, find.text('09:30').last);
    await _tap(tester, find.byKey(const ValueKey('save-availability')));
    expect(
      find.text('Промежуток должен быть не короче 1 часа.'),
      findsOneWidget,
    );
    expect(
      fixture.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );
  });

  testWidgets('a booked availability stays visible until removal succeeds', (
    tester,
  ) async {
    fixture.windows.add({
      'id': 'window-booked',
      'starts_at': '2099-01-01T06:00:00Z',
      'ends_at': '2099-01-01T19:00:00Z',
    });
    fixture.deletionConflicts = true;
    await _pump(tester, fixture);
    await _tap(tester, find.text('Расписание и свободное время'));
    await _tap(tester, find.byTooltip('Снять с публикации'));
    await _tap(tester, find.widgetWithText(TextButton, 'Снять с публикации'));
    expect(
      find.byKey(const ValueKey('availability-window-booked')),
      findsOneWidget,
    );
    expect(
      find.text(
        'На это время есть бронь или временная блокировка. Снять публикацию сейчас нельзя.',
      ),
      findsOneWidget,
    );
    fixture.deletionConflicts = false;
    await _tap(tester, find.byTooltip('Снять с публикации'));
    await _tap(tester, find.widgetWithText(TextButton, 'Снять с публикации'));
    expect(
      find.byKey(const ValueKey('availability-window-booked')),
      findsNothing,
    );
  });

  testWidgets('failed initial load can be retried and logout stays available', (
    tester,
  ) async {
    fixture.loadFails = true;
    var loggedOut = false;
    await _pump(tester, fixture, onLogout: () => loggedOut = true);
    expect(find.text('Не удалось загрузить кабинет клуба.'), findsOneWidget);
    fixture.loadFails = false;
    await _tap(tester, find.text('Повторить'));
    expect(find.text('Спортклуб «Арена»'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('club-logout')));
    expect(loggedOut, isTrue);
  });

  testWidgets('cancelling club and venue deletion sends no delete request', (
    tester,
  ) async {
    await _pump(tester, fixture);
    for (final target in ['club-club-owned', 'venue-court-owned']) {
      await _tap(tester, find.byKey(ValueKey('delete-managed-$target')));
      expect(
        find.textContaining('История бронирований сохранится.'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const ValueKey('cancel-delete-managed')));
    }
    expect(_deleteRequests(fixture), isEmpty);
    expect(
      find.byKey(const ValueKey('managed-venue-court-owned')),
      findsOneWidget,
    );
  });

  testWidgets(
    'confirmed venue deletion sends authenticated delete and keeps club',
    (tester) async {
      fixture.windows.add({
        'id': 'window-owned',
        'venue_id': 'court-owned',
        'starts_at': '2099-01-01T06:00:00Z',
        'ends_at': '2099-01-01T19:00:00Z',
      });
      await _pump(tester, fixture);
      await _tap(
        tester,
        find.byKey(const ValueKey('delete-managed-venue-court-owned')),
      );
      expect(
        find.text('Удалить площадку «Теннисный корт №1»?'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const ValueKey('confirm-delete-managed')));
      final request = _deleteRequests(fixture).single;
      expect(request.url.path, '/api/v1/club/venues/court-owned');
      expect(request.headers['authorization'], 'Bearer club-access');
      expect(
        find.byKey(const ValueKey('managed-venue-court-owned')),
        findsNothing,
      );
      expect(find.text('Спортклуб «Арена»'), findsOneWidget);
      expect(fixture.windows, isEmpty);
    },
  );

  testWidgets(
    'deleting last club removes children and keeps account name for recreation',
    (tester) async {
      await _pump(tester, fixture, accountClubName: 'Название аккаунта');
      await _tap(
        tester,
        find.byKey(const ValueKey('delete-managed-club-club-owned')),
      );
      expect(
        find.textContaining('Клуб и все его площадки исчезнут с карты.'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const ValueKey('confirm-delete-managed')));
      final request = _deleteRequests(fixture).single;
      expect(request.url.path, '/api/v1/club/clubs/club-owned');
      expect(request.headers['authorization'], 'Bearer club-access');
      expect(
        find.byKey(const ValueKey('managed-venue-court-owned')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('create-first-club')), findsOneWidget);
      expect(find.byKey(const ValueKey('club-dashboard')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('create-first-club')));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('club-name-field')),
            )
            .controller!
            .text,
        'Название аккаунта',
      );
    },
  );

  for (final isClub in [true, false]) {
    testWidgets('blocked ${isClub ? 'club' : 'venue'} deletion preserves data', (
      tester,
    ) async {
      fixture.deletionConflicts = true;
      await _pump(tester, fixture);
      final target = isClub ? 'club-club-owned' : 'venue-court-owned';
      await _tap(tester, find.byKey(ValueKey('delete-managed-$target')));
      await _tap(tester, find.byKey(const ValueKey('confirm-delete-managed')));
      expect(
        find.byKey(const ValueKey('managed-venue-court-owned')),
        findsOneWidget,
      );
      expect(find.text('Спортклуб «Арена»'), findsOneWidget);
      expect(
        find.text(
          'Нельзя удалить ${isClub ? 'клуб' : 'площадку'}: есть предстоящие бронирования, игры или временные блокировки. Дождитесь их завершения.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('retry-managed-operation')),
        findsOneWidget,
      );
      expect(_deleteRequests(fixture).length, 1);
    });
  }

  testWidgets('deleting selected club selects another club and its venues', (
    tester,
  ) async {
    _addSecondClub(fixture);
    await _pump(tester, fixture);
    await _tap(
      tester,
      find.byKey(const ValueKey('delete-managed-club-club-owned')),
    );
    await _tap(tester, find.byKey(const ValueKey('confirm-delete-managed')));
    expect(find.text('Второй клуб'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('managed-venue-court-second')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('managed-venue-court-owned')),
      findsNothing,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets(
    'pending deletion keeps data and blocks management and duplicate calls',
    (tester) async {
      _addSecondClub(fixture);
      final gate = Completer<void>();
      fixture.beforeDelete = () => gate.future;
      await _pump(tester, fixture);
      final deleteFinder = find.byKey(
        const ValueKey('delete-managed-club-club-owned'),
      );
      final originalDeleteAction = tester
          .widget<IconButton>(deleteFinder)
          .onPressed!;
      await _tap(tester, deleteFinder);
      await tester.tap(find.byKey(const ValueKey('confirm-delete-managed')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      originalDeleteAction();
      await tester.pump();
      expect(_deleteRequests(fixture).length, 1);
      expect(
        find.byKey(const ValueKey('managed-venue-court-owned')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('create-managed-venue')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widgetList<PrimaryButton>(find.byType(PrimaryButton))
            .singleWhere(
              (button) => button.label == 'Расписание и свободное время',
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('select-managed-club-club-owned')),
            )
            .onChanged,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('managed-venue-court-owned')),
        findsNothing,
      );
      expect(find.text('Второй клуб'), findsOneWidget);
    },
  );

  testWidgets('failed deletion retains venue and can be retried', (
    tester,
  ) async {
    fixture.deleteStatus = 503;
    await _pump(tester, fixture);
    await _tap(
      tester,
      find.byKey(const ValueKey('delete-managed-venue-court-owned')),
    );
    await _tap(tester, find.byKey(const ValueKey('confirm-delete-managed')));
    expect(
      find.text('Не удалось удалить площадку. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('managed-venue-court-owned')),
      findsOneWidget,
    );
    fixture.deleteStatus = 204;
    await _tap(tester, find.byKey(const ValueKey('retry-managed-operation')));
    await _tap(tester, find.byKey(const ValueKey('confirm-delete-managed')));
    expect(_deleteRequests(fixture).length, 2);
    expect(
      find.byKey(const ValueKey('managed-venue-court-owned')),
      findsNothing,
    );
  });

  testWidgets('failed refresh after deletion cannot restore the deleted club', (
    tester,
  ) async {
    _addSecondClub(fixture);
    fixture.loadFailsAfterDelete = true;
    await _pump(tester, fixture);
    await _tap(
      tester,
      find.byKey(const ValueKey('delete-managed-club-club-owned')),
    );
    await _tap(tester, find.byKey(const ValueKey('confirm-delete-managed')));
    expect(
      find.text('Удаление выполнено, но обновить кабинет не удалось.'),
      findsOneWidget,
    );
    expect(find.text('Второй клуб'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('managed-venue-court-owned')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('managed-venue-court-second')),
      findsOneWidget,
    );
    fixture.loadFails = false;
    await _tap(tester, find.byKey(const ValueKey('retry-managed-operation')));
    expect(find.byKey(const ValueKey('club-management-error')), findsNothing);
    expect(
      find.byKey(const ValueKey('managed-venue-court-owned')),
      findsNothing,
    );
    expect(_deleteRequests(fixture).length, 1);
  });
}

List<dynamic> _deleteRequests(ClubDashboardFixture fixture) =>
    fixture.requests.where((request) => request.method == 'DELETE').toList();

void _addSecondClub(ClubDashboardFixture fixture) {
  fixture.clubs.add({
    ...fixture.clubs.first,
    'id': 'club-second',
    'name': 'Второй клуб',
  });
  fixture.venues.add({
    ...fixture.venues.first,
    'id': 'court-second',
    'club_id': 'club-second',
    'name': 'Второе поле',
  });
}

Future<void> _pump(
  WidgetTester tester,
  ClubDashboardFixture fixture, {
  VoidCallback? onLogout,
  String? accountClubName,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: ClubDashboardScreen(
        api: fixture.client,
        onLogout: onLogout ?? () {},
        accountClubName: accountClubName,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  if (finder.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}
