import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/screens/games_screens.dart';
import 'package:sport_venue_app/src/screens/home_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 5, 24, 12);

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

  test('a notice reads its kind, its target and whether it was seen', () {
    final note = AppNotification.fromJson({
      'id': 'n1',
      'type': 'request_approved',
      'title': 'Вас взяли в игру',
      'body': 'Лужники, завтра 19:00',
      'created_at': '2026-05-24T09:00:00Z',
      'read_at': null,
      'game_id': 'g7',
    });

    expect(note.kind, NotificationKind.requestApproved);
    expect(note.gameId, 'g7');
    expect(note.read, isFalse);
    expect(
      AppNotification.fromJson({
        'id': 'n2',
        'type': 'something_new',
        'title': 'x',
        'created_at': '2026-05-24T09:00:00Z',
        'read_at': '2026-05-24T10:00:00Z',
      }).kind,
      NotificationKind.other,
    );
  });

  test('a server without notices yet leaves the bell empty, quietly', () async {
    final client = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient(
        (request) async => http.Response('{"detail":"Not Found"}', 404),
      ),
    );
    addTearDown(client.close);
    final app = AppController(now: now, api: client);
    addTearDown(app.dispose);
    client.setTokens(
      ApiTokenPair(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'bearer',
        expiresAt: DateTime.utc(2030),
      ),
    );

    await app.loadNotifications();

    expect(app.notifications, isEmpty);
    expect(app.unreadNotifications, 0);
  });

  testWidgets('the bell counts what is new and opens the list', (tester) async {
    phone(tester);
    final app = controller();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: HomeScreen(
              controller: app,
              onOpenSearch: () {},
              onOpenGames: () {},
            ),
          ),
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

    expect(app.unreadNotifications, 2);
    expect(find.byKey(const ValueKey('home-bell-badge')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-bell')));
    await tester.pumpAndSettle();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Вас взяли в игру'), findsOneWidget);
    // The new ones stay marked while the reader is looking at them, even
    // though opening the list has already counted them as seen.
    expect(find.byKey(const ValueKey('note-fresh')), findsNWidgets(2));
    expect(app.unreadNotifications, 0);

    await tester.tap(find.text('Вас взяли в игру'));
    await tester.pumpAndSettle();

    expect(find.byType(GameDetailScreen), findsOneWidget);
  });

  testWidgets('nothing yet says what will appear there', (tester) async {
    phone(tester);
    final app = controller()..notifications = [];
    final router = GoRouter(
      initialLocation: Routes.notifications,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(),
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

    expect(find.byKey(const ValueKey('notifications-empty')), findsOneWidget);
  });
}
