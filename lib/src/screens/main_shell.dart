import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/venue_picker.dart';
import 'booking_screens.dart';
import 'create_game_screen.dart';
import 'games_screens.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.controller,
    required this.onLogout,
  });

  final AppController controller;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // The home screen paints its own field under the status bar, so the
    // inset is each screen's business rather than the shell's.
    final screens = [
      HomeScreen(
        controller: widget.controller,
        onOpenSearch: () => setState(() => _tab = 1),
        onOpenGames: () => setState(() => _tab = 2),
      ),
      SafeArea(
        bottom: false,
        child: SearchScreen(controller: widget.controller),
      ),
      SafeArea(
        bottom: false,
        child: GamesScreen(controller: widget.controller),
      ),
      SafeArea(
        bottom: false,
        child: ProfileScreen(
          controller: widget.controller,
          onLogout: widget.onLogout,
        ),
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_tab), child: screens[_tab]),
      ),
      extendBody: true,
      bottomNavigationBar: _BottomNav(
        selectedIndex: _tab,
        onTab: (index) => setState(() => _tab = index),
        onCreate: _showCreateSheet,
      ),
    );
  }

  /// Booking from the tab bar names no club, so it asks for one instead of
  /// picking whichever happened to be first in the catalogue.
  Future<void> _startBooking() async {
    final venues = widget.controller.venues;
    if (venues.isEmpty) {
      showAppSnack(context, context.l10n.noVenuesAvailable);
      return;
    }
    final venue = await pickVenue(
      context,
      venues: venues,
      selected: null,
      sportOf: (venue) {
        for (final sport in widget.controller.sports) {
          if (sport.id == venue.sportIds.first) {
            return sport;
          }
        }
        return null;
      },
    );
    if (venue == null || !mounted) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BookingScreen(controller: widget.controller, venue: venue),
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.ink.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.createSheetTitle,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _SheetAction(
                  icon: Icons.sports_soccer_rounded,
                  title: context.l10n.createGameAction,
                  subtitle: context.l10n.createGameActionSubtitle,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateGameScreen(controller: widget.controller),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _SheetAction(
                  icon: Icons.calendar_month_rounded,
                  title: context.l10n.bookVenueAction,
                  subtitle: context.l10n.bookVenueActionSubtitle,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startBooking();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The tab bar: a capsule floating over the page, frosted so the content
/// shows through it, with the selection sliding between slots.
///
/// It sits on `extendBody`, so the page scrolls underneath — which is the
/// whole point of the blur, and why each tab screen keeps a tail of empty
/// space at the bottom.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onTab,
    required this.onCreate,
  });

  final int selectedIndex;
  final ValueChanged<int> onTab;
  final VoidCallback onCreate;

  /// Slot 2 holds the create button, so the four tabs live either side of it.
  static const _slotOfTab = [0, 1, 3, 4];
  static const _slots = 5;

  @override
  Widget build(BuildContext context) {
    // The bar has to be given a height, and the labels inside it grow with
    // the system font. Capped lower than elsewhere: it is pinned over the
    // content, so every pixel it takes is a pixel of the screen it covers.
    final height = context.scaled(AppTheme.tabBarHeight, max: 1.3);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: context.colors.ink.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                // Translucent, so the blur has something to do.
                color: context.colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(
                  // The rim that makes the capsule read as glass. White at
                  // this strength is a highlight on a light page and a glare
                  // on a dark one, so the dark theme takes a faint one.
                  color: context.colors.isDark
                      ? context.colors.ink.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / _slots;
                  return Stack(
                    children: [
                      // The selection flies across rather than blinking from
                      // one tab to the next.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        left: slot * _slotOfTab[selectedIndex] + 6,
                        top: 6,
                        width: slot - 12,
                        height: height - 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.colors.accentSoft,
                            borderRadius: BorderRadius.circular(
                              (height - 14) / 2,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _NavItem(
                            index: 0,
                            selectedIndex: selectedIndex,
                            label: context.l10n.navHome,
                            icon: Icons.home_rounded,
                            onTab: onTab,
                          ),
                          _NavItem(
                            index: 1,
                            selectedIndex: selectedIndex,
                            label: context.l10n.navSearch,
                            icon: Icons.search_rounded,
                            onTab: onTab,
                          ),
                          Expanded(
                            child: Center(
                              child: Semantics(
                                button: true,
                                label: context.l10n.navCreate,
                                child: GestureDetector(
                                  key: const ValueKey('create-fab'),
                                  onTap: onCreate,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.colors.accent,
                                    ),
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: context.colors.onAccent,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _NavItem(
                            index: 2,
                            selectedIndex: selectedIndex,
                            label: context.l10n.navGames,
                            icon: Icons.sports_soccer_rounded,
                            onTab: onTab,
                          ),
                          _NavItem(
                            index: 3,
                            selectedIndex: selectedIndex,
                            label: context.l10n.navProfile,
                            icon: Icons.person_rounded,
                            onTab: onTab,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.label,
    required this.icon,
    required this.onTab,
  });

  final int index;
  final int selectedIndex;
  final String label;
  final IconData icon;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          key: ValueKey('nav-$label'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onTab(index),
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              final color = Color.lerp(
                context.colors.muted,
                context.colors.accent,
                t,
              )!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 2),
                  // Five slots share the bar's width, so a label has about
                  // 80 logical pixels. Past a modest enlargement it would
                  // come out as "Глав…" — less use than the smaller word,
                  // and the icon above it carries the meaning anyway. A
                  // screen reader is given the label in full regardless.
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: context.colors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.dim),
        ],
      ),
    );
  }
}
