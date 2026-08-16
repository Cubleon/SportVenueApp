import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/screens/booking_screens.dart';
import 'package:sport_venue_app/src/screens/create_game_screen.dart';
import 'package:sport_venue_app/src/screens/games_screens.dart';
import 'package:sport_venue_app/src/screens/home_screen.dart';
import 'package:sport_venue_app/src/screens/sport_selection_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  final fixedNow = DateTime(2026, 5, 24);

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('registration, otp and sport onboarding reach main screen', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);

    await tester.pumpWidget(SportVenueApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();

    expect(find.textContaining('зарегистрироваться'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('phone-field')),
      '9000000000',
    );
    await tester.tap(find.textContaining('согласен'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('registration-continue')));
    await tester.pumpAndSettle();

    expect(find.text('введите код'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byKey(ValueKey('otp-$i')), '1');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('какой спорт?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sports-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(controller.isSignedIn, isTrue);
  });

  testWidgets('otp rejects non-demo code with error text', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);

    await tester.pumpWidget(SportVenueApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phone-field')),
      '9000000000',
    );
    await tester.tap(find.textContaining('согласен'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('registration-continue')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byKey(ValueKey('otp-$i')), '${i + 1}');
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('неверный код, попробуйте ещё раз'), findsOneWidget);
    expect(controller.isSignedIn, isFalse);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('sport selection requires at least one sport', (tester) async {
    _setPhoneSize(tester);
    var completed = false;

    await tester.pumpWidget(
      _Harness(
        child: SportSelectionScreen(
          sports: MockData.sports,
          initialSelection: const {},
          onContinue: (_) async {
            completed = true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('sports-continue')));
    await tester.pump();
    expect(completed, isFalse);

    await tester.ensureVisible(find.text('футбол'));
    await tester.tap(find.text('футбол'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sports-continue')));
    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets(
    'booking recalculates player share and creates booking on fake payment',
    (tester) async {
      _setPhoneSize(tester);
      final controller = AppController(now: fixedNow);
      final initialCount = controller.bookings.length;

      await tester.pumpWidget(
        _Harness(
          child: BookingScreen(
            controller: controller,
            venue: MockData.venues.first,
          ),
        ),
      );

      expect(find.textContaining('₽400'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('players-plus')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('players-plus')));
      await tester.pumpAndSettle();
      expect(find.textContaining('₽320'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('pay-share')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-payment')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(controller.bookings.length, initialCount + 1);
    },
  );

  testWidgets('cancelling an existing booking removes it from upcoming', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    final booking = controller.upcomingBookings.single;

    await tester.pumpWidget(
      _Harness(
        child: HomeScreen(
          controller: controller,
          onOpenSearch: () {},
          onOpenGames: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey('upcoming-booking-${booking.id}')));
    await tester.pumpAndSettle();

    expect(find.text('детали брони'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-payment')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cancel-booking')));
    await tester.pumpAndSettle();

    expect(controller.bookings.single.status, 'отменена');
    expect(controller.upcomingBookings, isEmpty);
    expect(
      find.byKey(ValueKey('upcoming-booking-${booking.id}')),
      findsNothing,
    );
    expect(find.text('у вас пока нет предстоящих броней'), findsOneWidget);
  });

  testWidgets('game join action updates mock participants', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    final before = controller.games.first.participants.length;

    await tester.pumpWidget(
      _Harness(child: GamesScreen(controller: controller)),
    );
    await tester.tap(find.byKey(const ValueKey('join-game-1')));
    await tester.pumpAndSettle();

    expect(controller.games.first.participants.length, before + 1);
  });

  testWidgets('create game happy path adds game and opens detail', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    final before = controller.games.length;

    await tester.pumpWidget(
      _Harness(child: CreateGameScreen(controller: controller)),
    );
    await tester.tap(find.byKey(const ValueKey('create-game-submit')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(controller.games.length, before + 1);
    expect(find.byKey(const ValueKey('detail-join-game')), findsOneWidget);
  });
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    );
  }
}
