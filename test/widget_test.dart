import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/formatters.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/screens/booking_screens.dart';
import 'package:sport_venue_app/src/screens/create_game_screen.dart';
import 'package:sport_venue_app/src/screens/games_screens.dart';
import 'package:sport_venue_app/src/screens/home_screen.dart';
import 'package:sport_venue_app/src/screens/profile_screen.dart';
import 'package:sport_venue_app/src/screens/sport_selection_screen.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
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
    await tester.tap(find.textContaining('Согласен'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('registration-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Введите код'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byKey(ValueKey('otp-$i')), '1');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Какой спорт?'), findsOneWidget);
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
    await tester.tap(find.textContaining('Согласен'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('registration-continue')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byKey(ValueKey('otp-$i')), '${i + 1}');
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Неверный код, попробуйте ещё раз'), findsOneWidget);
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

    await tester.ensureVisible(find.text('Футбол'));
    await tester.tap(find.text('Футбол'));
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

  testWidgets('the home calendar decides which day the page is about', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    final game = controller.games.first;

    await tester.pumpWidget(
      _Harness(
        child: HomeScreen(
          controller: controller,
          onOpenSearch: () {},
          onOpenGames: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing is played on the day the app opens on, and the page says so
    // rather than showing games from another day. The games sit below the
    // fold, so they have to be scrolled to before they exist at all.
    expect(find.text('Свободно вс 24 мая'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('home-screen')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('Открытых игр пока нет'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('home-screen')),
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey('home-date-${game.date.toIso8601String().substring(0, 10)}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Свободно ${AppFormatters.dateShort(game.date)}'),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('home-screen')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('Открытых игр пока нет'), findsNothing);
    expect(find.text(game.venue.name.capitalized), findsWidgets);
  });

  testWidgets('the home survives the reader doubling the text', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);

    await tester.pumpWidget(
      _Harness(
        textScale: 2,
        child: HomeScreen(
          controller: controller,
          onOpenSearch: () {},
          onOpenGames: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // An overflow paints a stripe and logs an error, which fails the test.
    // Scrolling the whole page is what exercises every box on it.
    for (var i = 0; i < 4; i++) {
      await tester.drag(
        find.byKey(const ValueKey('home-screen')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

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

    await tester.tap(find.byKey(ValueKey('booking-row-${booking.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Детали брони'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-payment')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cancel-booking')));
    await tester.pumpAndSettle();

    // A paid booking is not thrown away on one tap: the sheet asks first,
    // and backing out of it leaves the booking alone.
    expect(find.text('Отменить бронь?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-no')));
    await tester.pumpAndSettle();
    expect(controller.upcomingBookings, isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('cancel-booking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();

    expect(controller.bookings.single.statusCode, 'cancelled');
    expect(controller.upcomingBookings, isEmpty);
    expect(find.byKey(ValueKey('booking-row-${booking.id}')), findsNothing);
    expect(find.text('У вас пока нет предстоящих броней'), findsOneWidget);
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
    // The hours belong to the chosen club, so the button waits for them.
    await tester.pumpAndSettle();
    expect(find.text('20:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create-game-submit')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(controller.games.length, before + 1);
    // The organiser is in their own game, so it offers the way out.
    expect(find.byKey(const ValueKey('detail-leave-game')), findsOneWidget);
  });

  testWidgets('signing out asks first, and the avatar never shows a digit', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    controller.phone = '+7 (916) 123-45-67';
    var loggedOut = false;

    await tester.pumpWidget(
      _Harness(
        child: ProfileScreen(
          controller: controller,
          onLogout: () => loggedOut = true,
        ),
      ),
    );

    // The phone number starts with a 7 for everyone, so falling back to it
    // put the same digit in every avatar.
    expect(find.text('7'), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('logout-button')),
      200,
    );
    await tester.tap(find.byKey(const ValueKey('logout-button')));
    await tester.pumpAndSettle();

    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-no')));
    await tester.pumpAndSettle();
    expect(loggedOut, isFalse);

    await tester.tap(find.byKey(const ValueKey('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });

  testWidgets('a place in a game can be given back', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    final game = controller.games.first;

    await tester.pumpWidget(
      _Harness(
        child: GameDetailScreen(controller: controller, game: game),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('detail-join-game')));
    await tester.pumpAndSettle();

    final joined = controller.games.firstWhere((item) => item.id == game.id);
    expect(joined.participants.any((p) => p.isCurrentUser), isTrue);
    // The way in is replaced by the way out, not offered twice.
    expect(find.byKey(const ValueKey('detail-join-game')), findsNothing);

    // The snack floats over the pinned bar; let it go before tapping there.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('detail-leave-game')));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из игры?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-no')));
    await tester.pumpAndSettle();

    expect(
      controller.games
          .firstWhere((item) => item.id == game.id)
          .participants
          .any((p) => p.isCurrentUser),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('detail-leave-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();

    final left = controller.games.firstWhere((item) => item.id == game.id);
    expect(left.participants.any((p) => p.isCurrentUser), isFalse);
    expect(find.byKey(const ValueKey('detail-join-game')), findsOneWidget);
  });

  testWidgets('booking can change club without starting over', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);

    await tester.pumpWidget(
      _Harness(
        child: BookingScreen(
          controller: controller,
          venue: MockData.venues.first,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('₽400'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('booking-venue-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('venue-picker-search')),
      'север',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('venue-option-north')));
    await tester.pumpAndSettle();

    // A different club costs differently, and the summary follows it.
    expect(find.textContaining('₽400'), findsNothing);
    expect(find.textContaining('₽550'), findsWidgets);
  });

  testWidgets('the club picker searches, and picking one changes the step', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);

    await tester.pumpWidget(
      _Harness(child: CreateGameScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    // The step shows one club, not the whole catalogue.
    final field = find.byKey(const ValueKey('create-venue-field'));
    expect(field, findsOneWidget);
    expect(find.text('Арена север'), findsNothing);

    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('venue-picker-search')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('venue-picker-search')),
      'север',
    );
    await tester.pumpAndSettle();
    // The field underneath still names the current club, so the check is on
    // the options inside the sheet.
    expect(find.byKey(const ValueKey('venue-option-luzhniki')), findsNothing);
    expect(find.byKey(const ValueKey('venue-option-north')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('venue-option-north')));
    await tester.pumpAndSettle();
    expect(find.text('Арена север'), findsOneWidget);
  });

  // Haptics cannot be seen, and on the web preview they do nothing at all,
  // so the only way to know they fire is to listen on the channel they
  // travel down.
  testWidgets('choosing a sport ticks, and a booking knocks', (tester) async {
    _setPhoneSize(tester);
    final felt = _recordHaptics();
    final controller = AppController(now: fixedNow);

    await tester.pumpWidget(
      _Harness(
        child: SportSelectionScreen(
          sports: MockData.sports,
          initialSelection: const {},
          onContinue: (_) async {},
        ),
      ),
    );
    await tester.ensureVisible(find.text('Футбол'));
    await tester.tap(find.text('Футбол'));
    await tester.pumpAndSettle();

    expect(felt, ['HapticFeedbackType.selectionClick']);

    felt.clear();
    await tester.pumpWidget(
      _Harness(
        child: BookingConfirmationScreen(
          controller: controller,
          draft: BookingDraft(
            venue: MockData.venues.first,
            date: fixedNow.add(const Duration(days: 1)),
            durationMinutes: 60,
            startHour: 20,
            players: 4,
            mode: PaymentMode.split,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('confirm-payment')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(felt, ['HapticFeedbackType.mediumImpact']);
  });
}

/// Collects what the app asks the device to feel.
List<String> _recordHaptics() {
  final felt = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          felt.add(call.arguments as String);
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return felt;
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child, this.textScale = 1});

  final Widget child;

  /// The reader's text size. The layouts have to survive it, so a test can
  /// turn it up.
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      // The screens read their words from the same place the app does.
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: Scaffold(body: child),
    );
  }
}
