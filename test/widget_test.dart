import 'package:flutter/material.dart';
import 'package:sport_venue_app/src/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/formatters.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/screens/booking_screens.dart';
import 'package:sport_venue_app/src/screens/create_game_screen.dart';
import 'package:sport_venue_app/src/screens/games_screens.dart';
import 'package:sport_venue_app/src/screens/history_screen.dart';
import 'package:sport_venue_app/src/screens/home_screen.dart';
import 'package:sport_venue_app/src/screens/profile_screen.dart';
import 'package:sport_venue_app/src/screens/main_shell.dart';
import 'package:sport_venue_app/src/screens/sport_selection_screen.dart';
import 'package:sport_venue_app/src/widgets/shared_widgets.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  final fixedNow = DateTime(2026, 5, 24);

  setUpAll(() {});

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

  testWidgets('sport selection lets a reader say "anything"', (tester) async {
    _setPhoneSize(tester);
    Set<String>? saved;

    await tester.pumpWidget(
      _Harness(
        child: SportSelectionScreen(
          sports: MockData.sports,
          initialSelection: const {},
          onContinue: (ids) async {
            saved = ids;
          },
        ),
      ),
    );

    // Nothing ticked: the button offers the way past rather than greying
    // out, and passing through saves no preference at all.
    expect(find.textContaining('Пропустить'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sports-continue')));
    await tester.pump();
    expect(saved, isEmpty);

    await tester.ensureVisible(find.text('Футбол'));
    await tester.tap(find.text('Футбол'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Продолжить'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sports-continue')));
    await tester.pump();
    expect(saved, {'football'});
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
    expect(find.text('0 игр · 4 клуба рядом'), findsOneWidget);

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
    expect(find.text('1 игра · 4 клуба рядом'), findsOneWidget);
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

  testWidgets('paying opens the booking it just created', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    addTearDown(controller.dispose);
    final before = controller.bookings.length;

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

    // Not a toast over the previous screen: the money bought something, and
    // the screen that follows says what, and where it now lives.
    await tester.pumpAndSettle();
    expect(controller.bookings.length, before + 1);
    expect(find.text('Бронь создана'), findsOneWidget);
    expect(find.textContaining('Осталось собрать'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-created-booking')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cancel-booking')), findsOneWidget);
  });

  testWidgets('the keyboard can reach the home, and is seen when it does', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _Harness(
        child: MainShell(controller: controller, onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // The tabs, the date cards and the sport tiles were GestureDetectors,
    // which no amount of tabbing can reach.
    final tabs = find.byType(TapTarget);
    expect(tabs, findsWidgets);

    final node = tester.firstWidget<Focus>(
      find.descendant(
        of: find.byKey(const ValueKey('nav-Главная')),
        matching: find.byType(Focus),
        matchRoot: true,
      ),
    );
    expect(node.canRequestFocus, isTrue);

    // And pressing Enter on a focused tab does what a tap does.
    var tapped = 0;
    await tester.pumpWidget(
      _Harness(
        child: Center(
          child: TapTarget(
            onTap: () => tapped++,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      ),
    );
    Focus.of(tester.element(find.byType(SizedBox).first)).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('a request says what actually happened', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    addTearDown(controller.dispose);
    final game = controller.games.firstWhere(
      (item) => item.type == GameType.approval,
    );

    await tester.pumpWidget(
      _Harness(
        child: GameDetailScreen(controller: controller, game: game),
      ),
    );
    await tester.pumpAndSettle();

    // The button is a verb, and the screen is titled by what it is rather
    // than by how one gets in.
    expect(find.text('Игра'), findsOneWidget);
    expect(find.text('Подать заявку'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-join-game')));
    await tester.pumpAndSettle();

    // This backend puts the reader straight into the roster, so that is
    // what is reported — never "заявка отправлена" over a completed join.
    expect(find.text('Вы присоединились к игре'), findsOneWidget);
  });

  testWidgets('a booking is cancelled from «мои брони», and asks first', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    final booking = controller.upcomingBookings.single;

    await tester.pumpWidget(
      _Harness(
        child: HistoryScreen(
          controller: controller,
          focus: HistoryFocus.bookings,
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
    // A cancelled booking stays in the list: this screen is a history, and a
    // row that vanishes leaves a reader wondering whether it ever existed.
    expect(find.byKey(ValueKey('booking-row-${booking.id}')), findsOneWidget);
    expect(find.textContaining('отменена'), findsWidgets);
  });

  testWidgets('a game is read before it is joined', (tester) async {
    _setPhoneSize(tester);
    final controller = AppController(now: fixedNow);
    final game = controller.games.first;
    final before = game.participants.length;

    await tester.pumpWidget(
      _Harness(child: GamesScreen(controller: controller)),
    );

    // The card offers no shortcut: joining is only on the screen that shows
    // who is playing and what the rules are.
    expect(find.byKey(const ValueKey('join-game-1')), findsNothing);
    expect(find.text('Вступить'), findsNothing);

    await tester.tap(find.text(game.venue.name.capitalized).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('detail-join-game')));
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
    expect(find.byIcon(AppIcons.user), findsOneWidget);

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
