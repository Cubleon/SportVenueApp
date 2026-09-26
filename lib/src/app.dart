import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'data/app_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class SportVenueApp extends StatefulWidget {
  const SportVenueApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<SportVenueApp> createState() => _SportVenueAppState();
}

class _SportVenueAppState extends State<SportVenueApp> {
  late final AppController _controller =
      widget.controller ?? AppController.connected();
  final AppBoot _boot = AppBoot();

  /// Started with the app, awaited by the splash. A reader who signed in
  /// last week lands on the main screen instead of the phone field.
  late final Future<bool> _restoring = _controller.restoreSession();

  late final _router = buildRouter(
    controller: _controller,
    boot: _boot,
    restoring: _restoring,
  );

  @override
  void dispose() {
    _router.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
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
    );
  }
}
