import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_controller.dart';
import 'screens/auth_screens.dart';
import 'screens/main_shell.dart';
import 'screens/sport_selection_screen.dart';
import 'theme/app_theme.dart';

enum _RootStage { splash, registration, otp, sports, main }

class SportVenueApp extends StatefulWidget {
  const SportVenueApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<SportVenueApp> createState() => _SportVenueAppState();
}

class _SportVenueAppState extends State<SportVenueApp> {
  late final AppController _controller =
      widget.controller ?? AppController.connected();
  _RootStage _stage = _RootStage.splash;
  String _pendingPhone = '';

  /// Started with the app, awaited by the splash. A reader who signed in
  /// last week lands on the main screen instead of the phone field.
  late final Future<bool> _restoring;

  @override
  void initState() {
    super.initState();
    _restoring = _controller.restoreSession();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportVenue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // The reader's own setting decides. There is nowhere to keep a choice
      // of our own — the app stores nothing on the device yet — and a phone
      // set to dark at night is asking every app, not just this one.
      themeMode: ThemeMode.system,
      // The product is shaped for a phone. On a tablet or a desktop window
      // the layout used to stretch — a phone number field a metre wide — so
      // every route is held to a phone's width and centred, and the page
      // colour fills what is left. Wrapping the builder rather than each
      // screen also catches pushed routes, sheets and snack bars.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayStyle(context.colors),
        child: ColoredBox(
          color: context.colors.bg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: switch (_stage) {
              _RootStage.splash => SplashScreen(
                key: const ValueKey('splash'),
                // The mark stays up until the session question is settled,
                // which is the only thing this app has ever had to wait for.
                onFinished: () async {
                  var restored = false;
                  try {
                    restored = await _restoring;
                  } catch (_) {
                    // A session that will not come back is not an error to
                    // report; it just means signing in again.
                  }
                  if (!mounted) {
                    return;
                  }
                  setState(
                    () => _stage = restored
                        ? _RootStage.main
                        : _RootStage.registration,
                  );
                },
              ),
              _RootStage.registration => RegistrationScreen(
                key: const ValueKey('registration'),
                onContinue: (phone) async {
                  try {
                    await _controller.startPhoneVerification(phone);
                    if (!mounted) return null;
                    setState(() {
                      _pendingPhone = phone;
                      _stage = _RootStage.otp;
                    });
                    return null;
                  } catch (error) {
                    return _controller.messageFor(error);
                  }
                },
              ),
              _RootStage.otp => OtpScreen(
                key: const ValueKey('otp'),
                phone: _pendingPhone,
                onBack: () => setState(() => _stage = _RootStage.registration),
                onVerified: (code) async {
                  try {
                    await _controller.signIn(_pendingPhone, code);
                    if (!mounted) {
                      return null;
                    }
                    setState(() => _stage = _RootStage.sports);
                    return null;
                  } catch (error) {
                    return _controller.messageFor(error);
                  }
                },
                onResend: () async {
                  try {
                    await _controller.startPhoneVerification(_pendingPhone);
                    return null;
                  } catch (error) {
                    return _controller.messageFor(error);
                  }
                },
              ),
              _RootStage.sports => SportSelectionScreen(
                key: const ValueKey('sports'),
                sports: _controller.sports,
                initialSelection: _controller.selectedSportIds,
                errorMessage: _controller.messageFor,
                onContinue: (ids) async {
                  await _controller.completeSports(ids);
                  if (!mounted) {
                    return;
                  }
                  setState(() => _stage = _RootStage.main);
                },
              ),
              _RootStage.main => MainShell(
                key: const ValueKey('main'),
                controller: _controller,
                onLogout: () {
                  _controller.logout();
                  setState(() => _stage = _RootStage.registration);
                },
              ),
            },
          );
        },
      ),
    );
  }
}
