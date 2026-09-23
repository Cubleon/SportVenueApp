import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_controller.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// Pull-to-refresh, in the app's colours, over a scrolling screen.
///
/// The gesture is the one way a reader can ask for fresh data without
/// leaving the screen they are on, and every list here is a snapshot of
/// something a server owns — bookings get cancelled, games fill up.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.controller,
    required this.child,
  });

  final AppController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => refreshAndReport(context, controller),
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      // Clear of the screen's own title, which the pull drags down with it.
      displacement: 28,
      child: child,
    );
  }
}

/// Runs the refresh and says so if the server will not answer.
///
/// A pull that quietly does nothing is worse than no pull at all: the
/// reader is left believing they are looking at current data.
Future<void> refreshAndReport(
  BuildContext context,
  AppController controller,
) async {
  // The pull has taken. Said in the hand, before the waiting starts.
  await HapticFeedback.lightImpact();
  try {
    await controller.refresh();
  } catch (error) {
    if (context.mounted) {
      showAppSnack(context, controller.messageFor(error));
    }
  }
}
