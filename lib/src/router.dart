import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import 'data/app_controller.dart';
import 'labels.dart';
import 'models/sport_venue_models.dart';
import 'screens/auth_screens.dart';
import 'screens/email_auth_screens.dart';
import 'screens/booking_screens.dart';
import 'screens/booking_success_screen.dart';
import 'screens/create_game_screen.dart';
import 'screens/games_screens.dart';
import 'screens/history_screen.dart';
import 'screens/main_shell.dart';
import 'screens/payment_admin_screen.dart';
import 'screens/share_payment_screen.dart';
import 'screens/sport_selection_screen.dart';
import 'screens/venue_screen.dart';
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
  static const call = '/signin/call';
  static const email = '/signin/email';
  static const emailCode = '/signin/email/code';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const bookings = '/bookings';
  static const myGames = '/my-games';
  static const history = '/history';
  static String create({DateTime? date}) => date == null
      ? '/create'
      : '/create?date=${date.toIso8601String().substring(0, 10)}';

  static String game(String id) => '/game/$id';
  static String venue(String id, {DateTime? date}) =>
      _withDate('/venue/$id', date);

  /// Booking an hour at a club, which is a step past looking at it.
  static String book(String id, {DateTime? date}) =>
      _withDate('/venue/$id/book', date);

  static String _withDate(String path, DateTime? date) => date == null
      ? path
      : '$path?date=${date.toIso8601String().substring(0, 10)}';

  static String booking(String id) => '/booking/$id';

  /// The payments admin's queue: transfers to check, money to return.
  static const adminPayments = '/admin/payments';

  /// Paying the reader's share of a booking. [created] says the booking
  /// was made a moment ago, which the screen opens by saying so.
  /// The screen that says a booking was just made.
  static String created(String id) => '/booking/$id/created';

  static String pay(String id, {bool created = false}) =>
      '/booking/$id/pay${created ? '?new=1' : ''}';
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
          here == Routes.call ||
          here == Routes.email ||
          here == Routes.emailCode ||
          here == Routes.onboarding ||
          here == Routes.splash;
      if (!controller.isSignedIn) {
        if (here == Routes.call && controller.phoneChallenge == null) {
          return Routes.signIn;
        }
        if (here == Routes.emailCode && controller.emailChallenge == null) {
          return Routes.email;
        }
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
        // Signing in fires this guard while the call screen is still on
        // its way to onboarding, and taking the link here would hand it to
        // a redirect that onboarding then overwrites with the home screen —
        // which is how a link to a game ended at «Главная».
        return boot.onboarded ? boot.take() : Routes.onboarding;
      }
      return null;
    },
    routes: [
      appRoute(
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
      appRoute(
        path: Routes.signIn,
        builder: (context, state) => RegistrationScreen(
          onEmail: () => context.go(Routes.email),
          onContinue: (phone) async {
            final l10n = context.l10n;
            // The demo has no server to call back. Signing in moves the
            // guard, which takes the reader on from here.
            if (controller.isDemo) {
              controller.signInDemo(phone: phone);
              return null;
            }
            try {
              await controller.startPhoneVerification(phone);
              if (!context.mounted) return null;
              boot.pendingPhone = phone;
              context.go(Routes.call);
              return null;
            } catch (error) {
              return errorTextFor(l10n, error);
            }
          },
        ),
      ),
      appRoute(
        path: Routes.email,
        builder: (context, state) => EmailSignInScreen(
          onBack: () {
            controller.cancelEmailVerification();
            context.go(Routes.signIn);
          },
          onContinue: (email) async {
            final l10n = context.l10n;
            if (controller.isDemo) {
              controller.signInDemo(email: email);
              return null;
            }
            try {
              await controller.startEmailVerification(email);
              if (context.mounted) context.go(Routes.emailCode);
              return null;
            } catch (error) {
              return errorTextFor(l10n, error);
            }
          },
        ),
      ),
      appRoute(
        path: Routes.emailCode,
        builder: (context, state) => EmailVerificationScreen(
          email: controller.email,
          challenge: controller.emailChallenge!,
          onVerify: controller.verifyEmailCode,
          onResend: () => controller.startEmailVerification(controller.email),
          onBack: () => context.go(Routes.email),
          onCancel: controller.cancelEmailVerification,
          codeAccepted: () => controller.emailCodeAccepted,
        ),
      ),
      appRoute(
        path: Routes.call,
        builder: (context, state) => CallVerificationScreen(
          phone: boot.pendingPhone,
          challenge: controller.phoneChallenge!,
          onBack: () => context.go(Routes.signIn),
          onCheck: controller.checkPhoneVerification,
          onCancel: controller.cancelPhoneVerification,
          onRestart: () => controller.startPhoneVerification(boot.pendingPhone),
        ),
      ),
      appRoute(
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
      appRoute(
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

/// A route whose screen opens with the app's own transition and can be
/// swiped back from the left edge.
///
/// go_router picks the kind of page by looking for a `MaterialApp` above it,
/// but it looks for the one in `material_ui`, and this app's `MaterialApp`
/// is Flutter's own. Not finding it, go_router took the app for a bare
/// `WidgetsApp` and built every screen as a page with no transition at all:
/// screens snapped into place, and the swipe back had nothing to live on.
/// Building the page here does not depend on that guess.
GoRoute appRoute({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    routes: routes,
    pageBuilder: (context, state) => MaterialPage<void>(
      key: state.pageKey,
      name: state.name ?? state.matchedLocation,
      arguments: state.pathParameters,
      restorationId: state.pageKey.value,
      child: builder(context, state),
    ),
  );
}

/// The screens that open over the shell, as routes.
///
/// Shared with the widget tests, which push these same locations: one route
/// table means a test cannot pass against a path the app does not have.
List<RouteBase> shellRoutes(AppController controller) => [
  appRoute(
    path: 'game/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      // A friend's link: the game may not be in the feed this phone has.
      return _OpenByLink<Game>(
        key: ValueKey('open-game-$id'),
        title: context.l10n.game,
        missing: context.l10n.gameNotFound,
        known: () => controller.gameById(id),
        load: () => controller.openGame(id),
        found: (game) => GameDetailScreen(controller: controller, game: game),
      );
    },
  ),
  appRoute(
    path: 'venue/:id',
    builder: (context, state) {
      final venue = _venueById(controller, state);
      if (venue == null) {
        return _NotFound(what: context.l10n.venueNotFound);
      }
      return VenueScreen(
        controller: controller,
        venue: venue,
        date: _dateOf(state),
      );
    },
    routes: [
      appRoute(
        path: 'book',
        builder: (context, state) {
          final venue = _venueById(controller, state);
          if (venue == null) {
            return _NotFound(what: context.l10n.venueNotFound);
          }
          return BookingScreen(
            controller: controller,
            venue: venue,
            date: _dateOf(state),
          );
        },
      ),
    ],
  ),
  appRoute(
    path: 'booking/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      // An invite to pay a share: the booking is usually someone else's,
      // so it is fetched by its id rather than looked up in «Мои брони».
      return _OpenByLink<Booking>(
        key: ValueKey('open-booking-$id'),
        title: context.l10n.bookingDetails,
        missing: context.l10n.bookingNotFound,
        known: () => controller.bookingById(id),
        load: () => controller.openBooking(id),
        found: (booking) =>
            BookingDetailsScreen(controller: controller, booking: booking),
      );
    },
    routes: [
      appRoute(
        path: 'created',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          if (controller.bookingById(id) == null) {
            return _NotFound(what: context.l10n.bookingNotFound);
          }
          return BookingSuccessScreen(controller: controller, bookingId: id);
        },
      ),
      appRoute(
        path: 'pay',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          if (controller.bookingById(id) == null) {
            return _NotFound(what: context.l10n.bookingNotFound);
          }
          return SharePaymentScreen(
            controller: controller,
            bookingId: id,
            justCreated: state.uri.queryParameters['new'] == '1',
          );
        },
      ),
    ],
  ),
  appRoute(
    path: 'admin/payments',
    builder: (context, state) => controller.isPaymentAdmin
        ? PaymentAdminScreen(controller: controller)
        : _NotFound(
            what: context.l10n.adminOnly,
            hint: context.l10n.adminOnlyHint,
          ),
  ),
  appRoute(
    path: 'bookings',
    builder: (context, state) => HistoryScreen(
      controller: controller,
      focus: HistoryFocus.bookings,
      onFindVenues: () => openSearchTab(context),
    ),
  ),
  appRoute(
    path: 'my-games',
    builder: (context, state) => HistoryScreen(
      controller: controller,
      focus: HistoryFocus.games,
      onFindGames: () => openGamesTab(context),
    ),
  ),
  appRoute(
    path: 'history',
    builder: (context, state) =>
        HistoryScreen(controller: controller, focus: HistoryFocus.all),
  ),
  appRoute(
    path: 'create',
    builder: (context, state) => CreateGameScreen(
      controller: controller,
      date: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
    ),
  ),
];

Venue? _venueById(AppController controller, GoRouterState state) => controller
    .venues
    .where((item) => item.id == state.pathParameters['id'])
    .firstOrNull;

DateTime? _dateOf(GoRouterState state) =>
    DateTime.tryParse(state.uri.queryParameters['date'] ?? '');

/// Comes back to the shell with the games tab up.
void openGamesTab(BuildContext context) {
  MainShell.requestedTab.value = 2;
  context.go(Routes.home);
}

/// The same for the clubs: the search tab, with its map and list.
void openSearchTab(BuildContext context) {
  MainShell.requestedTab.value = 1;
  context.go(Routes.home);
}

/// Opens what a link points at: at once when this phone already has it,
/// after asking the server when it does not.
///
/// Before it, a link to a friend's booking always ended at «Бронь не
/// найдена»: the route only looked in the reader's own list.
class _OpenByLink<T extends Object> extends StatefulWidget {
  const _OpenByLink({
    super.key,
    required this.title,
    required this.missing,
    required this.known,
    required this.load,
    required this.found,
  });

  final String title;
  final String missing;
  final T? Function() known;
  final Future<T?> Function() load;
  final Widget Function(T value) found;

  @override
  State<_OpenByLink<T>> createState() => _OpenByLinkState<T>();
}

class _OpenByLinkState<T extends Object> extends State<_OpenByLink<T>> {
  late Future<T?> _loading;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    // Asked even when the thing is known, so what is shown is fresh; a
    // failure then is not worth an error, so it is marked as handled.
    _loading = widget.load()..ignore();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The spinner, the error and the screen it was waiting for replace one
    // another the way screens do, rather than snapping.
    return RiseFadeSwitcher(child: _view(context));
  }

  Widget _view(BuildContext context) {
    final known = widget.known();
    if (known != null) {
      return KeyedSubtree(
        key: const ValueKey('link-found'),
        child: widget.found(known),
      );
    }
    return FutureBuilder<T?>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _LinkWaiting(
            key: const ValueKey('link-waiting'),
            title: widget.title,
            onBack: _back,
          );
        }
        final error = snapshot.error;
        if (error != null) {
          return _LinkWaiting(
            key: const ValueKey('link-failed'),
            title: widget.title,
            onBack: _back,
            failure: RetryNotice(
              key: const ValueKey('link-retry'),
              message: errorText(context, error),
              onRetry: () => setState(_start),
            ),
          );
        }
        final value = snapshot.data;
        if (value == null) {
          return _NotFound(
            key: const ValueKey('link-missing'),
            what: widget.missing,
          );
        }
        return KeyedSubtree(
          key: const ValueKey('link-found'),
          child: widget.found(value),
        );
      },
    );
  }
}

/// The screen a link stands on while it loads, or after it could not.
class _LinkWaiting extends StatelessWidget {
  const _LinkWaiting({
    super.key,
    required this.title,
    required this.onBack,
    this.failure,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? failure;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(title: title, onBack: onBack),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child:
                      failure ??
                      const CircularProgressIndicator(
                        key: ValueKey('link-loading'),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a link to something that is gone, or not loaded yet, arrives at.
class _NotFound extends StatelessWidget {
  const _NotFound({super.key, required this.what, this.hint});

  final String what;

  /// Why it is not here. A missing booking is a stale link; a screen the
  /// reader may not open is not, and saying so sent them looking for one.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    // Laid out like every other inner screen — a title bar with the way
    // back, the card under it. Centred on its own, the card stretched to
    // the full height of the page and there was no back button at all.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenTitleBar(
              title: '',
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.home);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EmptyState(
                icon: AppIcons.searchX,
                title: what,
                description: hint ?? context.l10n.notFoundHint,
                actionLabel: context.l10n.toHome,
                onAction: () => context.go(Routes.home),
              ),
            ),
          ],
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
