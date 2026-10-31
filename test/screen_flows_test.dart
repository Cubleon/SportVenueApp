import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/screens/games_screens.dart';
import 'package:sport_venue_app/src/screens/home_screen.dart';
import 'package:sport_venue_app/src/screens/main_shell.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';
import 'package:sport_venue_app/src/widgets/shared_widgets.dart';

/// The flows added last, driven through their screens rather than the
/// controller: what the reader taps, and what the screen says back.
void main() {
  final now = DateTime(2026, 5, 24, 12);
  final tomorrow = DateTime(2026, 5, 25);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AppController controller() {
    final app = AppController(now: now);
    addTearDown(app.dispose);
    return app;
  }

  Future<void> open(
    WidgetTester tester,
    AppController app,
    String location,
  ) async {
    phone(tester);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: SizedBox(key: ValueKey('home'))),
          routes: shellRoutes(app),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('a game «по одобрению»', () {
    testWidgets('asking in is a request, and it can be taken back', (
      tester,
    ) async {
      final app = controller();
      final first = app.games.first;
      app.games = [
        first.copyWith(type: GameType.approval),
        ...app.games.skip(1),
      ];
      await open(tester, app, Routes.game(first.id));

      expect(find.text('Подать заявку'), findsOneWidget);
      await tap(tester, 'detail-join-game');

      // A request takes no seat, so there is nothing to pay yet.
      expect(find.byKey(const ValueKey('detail-withdraw-request')), findsOne);
      expect(find.byKey(const ValueKey('detail-pay-share')), findsNothing);

      // The note that the request went covers the bar for a few seconds.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tap(tester, 'detail-withdraw-request');
      // Asked as a request, not as leaving a seat the reader never had.
      expect(find.text('Отозвать заявку?'), findsOneWidget);
      expect(find.text('Выйти из игры?'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('confirm-yes')));
      await tester.pumpAndSettle();
      expect(find.text('Заявка отозвана'), findsOneWidget);

      expect(find.byKey(const ValueKey('detail-join-game')), findsOne);
      expect(app.games.first.readerRequested, isFalse);
    });

    testWidgets('the organiser lets a request in from the game screen', (
      tester,
    ) async {
      final app = controller();
      final game = await app.createGame(
        sportId: 'football',
        venue: MockData.venues.first,
        date: tomorrow,
        startHour: 20,
        durationMinutes: 60,
        capacity: 4,
        type: GameType.approval,
        genderFilter: GenderFilter.any,
      );
      const ivan = Participant(
        id: 'ivan',
        name: 'Иван Петров',
        initial: 'И',
        rating: 0,
        status: 'pending',
      );
      app.games = [
        for (final item in app.games)
          item.id == game.id
              ? item.copyWith(participants: [...item.participants, ivan])
              : item,
      ];
      await open(tester, app, Routes.game(game.id));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('request-ivan')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, 'request-approve');

      final current = app.games.firstWhere((item) => item.id == game.id);
      expect(current.requests, isEmpty);
      expect(current.players.any((p) => p.sameAs(ivan)), isTrue);
      expect(find.byKey(const ValueKey('request-ivan')), findsNothing);
    });
  });

  testWidgets('the organiser cancels a game, after saying yes', (tester) async {
    final app = controller();
    final game = await app.createGame(
      sportId: 'football',
      venue: MockData.venues.first,
      date: tomorrow,
      startHour: 20,
      durationMinutes: 60,
      capacity: 4,
      type: GameType.open,
      genderFilter: GenderFilter.any,
    );
    await open(tester, app, Routes.game(game.id));

    await tap(tester, 'detail-cancel-game');
    expect(find.text('Отменить игру?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();

    expect(find.text('Игра отменена'), findsOneWidget);
    expect(app.gameIsOff(app.games.firstWhere((g) => g.id == game.id)), isTrue);
    // Nothing is left to do on a game that is off.
    expect(find.byKey(const ValueKey('detail-cancel-game')), findsNothing);
    expect(find.byKey(const ValueKey('detail-join-game')), findsNothing);
  });

  testWidgets('a game opens by its link', (tester) async {
    final app = controller();
    final game = app.games.first;
    await open(tester, app, Routes.game(game.id));

    expect(find.byType(GameDetailScreen), findsOneWidget);
    expect(find.text('Игра не найдена'), findsNothing);
  });

  group('with nothing in it yet', () {
    testWidgets('«Мои брони» sends the reader to the clubs', (tester) async {
      final app = controller()..bookings = [];
      MainShell.requestedTab.value = 0;
      addTearDown(() => MainShell.requestedTab.value = 0);
      await open(tester, app, Routes.bookings);

      expect(find.text('Броней пока нет'), findsOneWidget);
      await tester.tap(find.text('Найти площадку'));
      await tester.pumpAndSettle();

      expect(MainShell.requestedTab.value, 1);
      expect(find.byKey(const ValueKey('home')), findsOneWidget);
    });

    testWidgets('the games tab offers to make one', (tester) async {
      phone(tester);
      final app = controller()..games = [];
      String? went;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => GamesScreen(controller: app),
          ),
          GoRoute(
            path: '/create',
            builder: (context, state) {
              went = state.uri.toString();
              return const SizedBox();
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('games-empty')), findsOneWidget);
      await tester.tap(find.text('Создать игру'));
      await tester.pumpAndSettle();

      expect(went, Routes.create());
    });

    testWidgets('a booking with unpaid places hands over a reminder', (
      tester,
    ) async {
      final app = controller();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, app, Routes.booking('booking-demo'));

      await tap(tester, 'remind-to-pay');

      expect(copied, contains('₽525'));
      expect(copied, contains('Академия спорта'));
      expect(copied, contains('бронь снимется'));
      expect(find.textContaining('Напоминание скопировано'), findsOneWidget);
    });

    testWidgets('the search on the home clears in one tap', (tester) async {
      phone(tester);
      final app = controller();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: HomeScreen(
              controller: app,
              onOpenSearch: () {},
              onOpenGames: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-search-clear')), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'лужники');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-search-clear')));
      await tester.pumpAndSettle();

      expect(find.text('лужники'), findsNothing);
      expect(find.byKey(const ValueKey('home-search-clear')), findsNothing);
    });

    testWidgets('no clubs at all is not blamed on a filter', (tester) async {
      phone(tester);
      final app = controller()..venues = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: HomeScreen(
              controller: app,
              onOpenSearch: () {},
              onOpenGames: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final empty = find.byKey(const ValueKey('home-no-clubs'));
      await tester.scrollUntilVisible(
        empty,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Клубов пока нет'), findsOneWidget);
      expect(find.text('Сбросить'), findsNothing);
    });

    testWidgets('the payments screen tells a player it is not theirs', (
      tester,
    ) async {
      final app = controller()..isPaymentAdmin = false;
      await open(tester, app, Routes.adminPayments);

      expect(
        find.text('Этот раздел только для администратора оплат.'),
        findsOneWidget,
      );
      // Not a stale link: nothing was deleted, the screen is just not theirs.
      expect(
        find.text('Возможно, ссылка устарела или запись удалили.'),
        findsNothing,
      );
      expect(find.byType(BackCircleButton), findsOneWidget);
    });
  });
}
