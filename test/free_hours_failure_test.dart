import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/screens/home_screen.dart';
import 'package:sport_venue_app/src/screens/venue_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

/// A server that is down until it is told to come back, and then has no
/// free hours anywhere — enough to tell "failed" from "answered" apart.
class _FlakyServer {
  _FlakyServer() {
    client = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient((request) async {
        if (down) {
          throw http.ClientException('offline', request.url);
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  late final SportVenueApiClient client;
  bool down = true;
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  final fixedNow = DateTime(2026, 5, 24);

  testWidgets('a club whose free hours did not load says so, and asks again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = _FlakyServer();
    addTearDown(server.client.close);
    final controller = AppController(now: fixedNow, api: server.client);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(VenueScreen(controller: controller, venue: MockData.venues.first)),
    );
    await tester.pumpAndSettle();

    // Not «считаем…» for ever: the row gives up, and says how to try again.
    expect(find.text('считаем…'), findsNothing);
    expect(find.text('нет данных'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('venue-free-hours-failed')),
      findsOneWidget,
    );

    server.down = false;
    await tester.ensureVisible(find.text('Повторить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('venue-free-hours-failed')), findsNothing);
    expect(find.textContaining('0 часов'), findsOneWidget);
  });

  testWidgets('the home stops waiting for free hours that did not load', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = _FlakyServer();
    addTearDown(server.client.close);
    final controller = AppController(now: fixedNow, api: server.client);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        HomeScreen(
          controller: controller,
          onOpenSearch: () {},
          onOpenGames: () {},
        ),
      ),
    );
    // Settling at all is part of the test: a placeholder that shimmers for
    // ever would keep the frame scheduler busy and this would time out.
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-free-hours-failed')),
      findsOneWidget,
    );
    expect(find.textContaining('свободно'), findsNothing);

    server.down = false;
    await tester.ensureVisible(find.text('Повторить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-free-hours-failed')), findsNothing);
    expect(find.text('свободно 0 часов'), findsWidgets);
  });
}
