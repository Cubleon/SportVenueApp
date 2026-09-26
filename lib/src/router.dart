import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import 'data/app_controller.dart';
import 'labels.dart';
import 'models/sport_venue_models.dart';
import 'screens/auth_screens.dart';
import 'screens/booking_screens.dart';
import 'screens/create_game_screen.dart';
import 'screens/games_screens.dart';
import 'screens/history_screen.dart';
import 'screens/main_shell.dart';
import 'screens/sport_selection_screen.dart';
import 'theme/app_icons.dart';
import 'widgets/shared_widgets.dart';

/// Every place in the app that has an address.
///
/// Until this existed the app lived at one URL: navigation was a stack of
/// `MaterialPageRoute`s and the browser bar never moved, so a game could not
/// be linked to, a club could not be sent to anyone, and a reload always
/// landed back at the beginning. For a product whose whole loop is "скинь
/// ссылку в чат", that was the loop missing.
abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/signin';
  static const code = '/signin/code';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const bookings = '/bookings';
  static const myGames = '/my-games';
  static const history = '/history';
  static String create({DateTime? date}) => date == null
      ? '/create'
      : '/create?date=${date.toIso8601String().substring(0, 10)}';

  static String game(String id) => '/game/$id';
  static String venue(String id, {DateTime? date}) {
    final path = '/venue/$id';
    if (date == null) {
      return path;
    }
    return '$path?date=${date.toIso8601String().substring(0, 10)}';
  }

  static String booking(String id) => '/booking/$id';
}

/// A link to somewhere in the app, ready to be pasted into a chat.
///
/// The router keeps the hash strategy, which is what makes the app work on
/// any static host without server rewrites — so the shareable form of a
/// location is this page's own URL with the location in its fragment.
/// Off the web there is no such address until a universal-link domain is
/// configured, and [canShareLinks] is false rather than handing anyone a
/// `file://` link that goes nowhere.
bool get canShareLinks => kIsWeb;

String shareLink(String location) =>
    Uri.base.replace(fragment: location).toString();

/// What the app was asked for before it was ready to answer.
///
/// A cold start that arrives at `/game/g7` has no session yet, no games
/// loaded, and nothing to show. The destination is parked here, the splash
/// settles the session question, and sign-in — if it is needed at all —
/// hands the reader on to where they were going rather than to the home
/// screen, which is not where the link pointed.
class AppBoot {
  bool ready = false;

  /// Set when onboarding has been answered, so the browser's back button
  /// cannot walk the reader back into it.
  bool onboarded = false;
  String? _parked;
  String pendingPhone = '';

  void park(String location) {
    if (location == Routes.splash) {
      return;
    }
    _parked ??= location;
  }

  String take({String fallback = Routes.home}) {
    final parked = _parked;
    _parked = null;
    return parked ?? fallback;
  }
}

/// Fires when the answer to "is anyone signed in" changes, and not when
/// anything else about the app's data does.
class _AuthChanges extends ChangeNotifier {
  _AuthChanges(this._controller) : _signedIn = _controller.isSignedIn {
    _controller.addListener(_check);
  }

  final AppController _controller;
  bool _signedIn;

  void _check() {
    final now = _controller.isSignedIn;
    if (now != _signedIn) {
      _signedIn = now;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_check);
    super.dispose();
  }
}

GoRouter buildRouter({
  required AppController controller,
  required AppBoot boot,
  required Future<bool> restoring,
}) {
  return GoRouter(
    initialLocation: Routes.home,
    // Only a sign-in or a sign-out re-runs the guard. Listening to the
    // controller itself would rebuild the whole route tree on every join,
    // cancellation and refresh — work nobody asked for, and enough to pull
    // an open sheet out from under the reader mid-decision.
    refreshListenable: _AuthChanges(controller),
    redirect: (context, state) {
      final here = state.uri.toString();
      if (!boot.ready) {
        boot.park(here);
        return here == Routes.splash ? null : Routes.splash;
      }
      final authArea =
          here == Routes.signIn ||
          here == Routes.code ||
          here == Routes.onboarding ||
          here == Routes.splash;
      if (!controller.isSignedIn) {
        if (authArea) {
          return null;
        }
        boot.park(here);
        return Routes.signIn;
      }
      // Signed in and still standing on a door. Onboarding is the one screen
      // that comes after signing in, so it stays open — until it has been
      // answered, after which it is a door like the others.
      if (authArea && !(here == Routes.onboarding && !boot.onboarded)) {
        // Only the far side of onboarding gets to spend the parked link.
        // Signing in fires this guard while the code screen is still on
        // its way to onboarding, and taking the link here would hand it to
        // a redirect that onboarding then overwrites with the home screen —
        // which is how a link to a game ended at «Главная».
        return boot.onboarded ? boot.take() : Routes.onboarding;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => SplashScreen(
          onFinished: () async {
            var restored = false;
            try {
              restored = await restoring;
            } catch (_) {
              // A session that will not come back is not an error to report;
              // it just means signing in again.
            }
            boot.ready = true;
            // A session that came back is an account that answered the
            // sports question long ago.
            boot.onboarded = restored;
            if (!context.mounted) {
              return;
            }
            context.go(restored ? boot.take() : Routes.signIn);
          },
        ),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => RegistrationScreen(
          onContinue: (phone) async {
            try {
              await controller.startPhoneVerification(phone);
              if (!context.mounted) return null;
              boot.pendingPhone = phone;
              context.go(Routes.code);
              return null;
            } catch (error) {
              return errorTextFor(context.l10n, error);
            }
          },
        ),
      ),
      GoRoute(
        path: Routes.code,
        builder: (context, state) => OtpScreen(
          phone: boot.pendingPhone,
          // Read before any await: these callbacks report failures long
          // after this context stopped being theirs to use.
          onBack: () => context.go(Routes.signIn),
          onVerified: (code) async {
            try {
              await controller.signIn(boot.pendingPhone, code);
              if (!context.mounted) return null;
              context.go(Routes.onboarding);
              return null;
            } catch (error) {
              return errorTextFor(context.l10n, error);
            }
          },
          onResend: () {
            final l10n = context.l10n;
            return controller
                .startPhoneVerification(boot.pendingPhone)
                .then<String?>((_) => null)
                .catchError((Object error) => errorTextFor(l10n, error));
          },
        ),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => SportSelectionScreen(
          sports: controller.sports,
          // Signing up starts from nothing ticked. Three sports chosen on the
          // reader's behalf are three they never said they play, and the feed
          // spends the rest of the session acting on them.
          initialSelection: const <String>{},
          errorMessage: (error) => errorTextFor(context.l10n, error),
          onContinue: (ids) async {
            await controller.completeSports(ids);
            boot.onboarded = true;
            if (!context.mounted) return;
            // Straight on to the link that started all this, if there was
            // one. Landing on the home screen after following a link to a
            // game is the app forgetting what it was asked for.
            context.go(boot.take());
          },
        ),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => MainShell(
          controller: controller,
          onLogout: () {
            controller.logout();
            context.go(Routes.signIn);
          },
        ),
        routes: shellRoutes(controller),
      ),
    ],
  );
}

/// The screens that open over the shell, as routes.
///
/// Shared with the widget tests, which push these same locations: one route
/// table means a test cannot pass against a path the app does not have.
List<RouteBase> shellRoutes(AppController controller) => [
  GoRoute(
    path: 'game/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      final game = controller.games.where((item) => item.id == id).firstOrNull;
      if (game == null) {
        return _NotFound(what: context.l10n.gameNotFound);
      }
      return GameDetailScreen(controller: controller, game: game);
    },
  ),
  GoRoute(
    path: 'venue/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      final venue = controller.venues
          .where((item) => item.id == id)
          .firstOrNull;
      if (venue == null) {
        return _NotFound(what: context.l10n.venueNotFound);
      }
      return BookingScreen(
        controller: controller,
        venue: venue,
        date: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
      );
    },
  ),
  GoRoute(
    path: 'booking/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      final booking = controller.bookings
          .where((item) => item.id == id)
          .firstOrNull;
      if (booking == null) {
        return _NotFound(what: context.l10n.bookingNotFound);
      }
      return BookingDetailsScreen(controller: controller, booking: booking);
    },
  ),
  GoRoute(
    path: 'bookings',
    builder: (context, state) =>
        HistoryScreen(controller: controller, focus: HistoryFocus.bookings),
  ),
  GoRoute(
    path: 'my-games',
    builder: (context, state) => HistoryScreen(
      controller: controller,
      focus: HistoryFocus.games,
      onFindGames: () => openGamesTab(context),
    ),
  ),
  GoRoute(
    path: 'history',
    builder: (context, state) =>
        HistoryScreen(controller: controller, focus: HistoryFocus.all),
  ),
  GoRoute(
    path: 'create',
    builder: (context, state) => CreateGameScreen(
      controller: controller,
      date: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
    ),
  ),
];

/// Comes back to the shell with the games tab up.
void openGamesTab(BuildContext context) {
  MainShell.requestedTab.value = 2;
  context.go(Routes.home);
}

/// What a link to something that is gone, or not loaded yet, arrives at.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.what});

  final String what;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(
              icon: AppIcons.searchX,
              title: what,
              description: context.l10n.notFoundHint,
              actionLabel: context.l10n.toHome,
              onAction: () => context.go(Routes.home),
            ),
          ),
        ),
      ),
    );
  }
}

/// Copies a link to somewhere in the app and says so.
Future<void> copyLink(BuildContext context, String location) async {
  await Clipboard.setData(ClipboardData(text: shareLink(location)));
  if (!context.mounted) {
    return;
  }
  showAppSnack(context, context.l10n.linkCopied, tone: SnackTone.done);
}

/// Kept here so the screens that offer a game can build its address without
/// reaching for the router's internals.
String gameLocation(Game game) => Routes.game(game.id);
