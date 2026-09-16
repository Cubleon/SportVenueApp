import 'package:flutter/material.dart';

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
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: switch (_stage) {
              _RootStage.splash => SplashScreen(
                key: const ValueKey('splash'),
                onFinished: () =>
                    setState(() => _stage = _RootStage.registration),
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
