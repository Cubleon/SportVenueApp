import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_icons.dart';

import '../../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../theme/app_theme.dart';
import '../router.dart';
import '../widgets/shared_widgets.dart';
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

  /// A tab asked for from outside the shell.
  ///
  /// Screens pushed over the shell — «Мои игры» and its «Найти игру» — sit
  /// above it in the navigator rather than inside it, so they cannot reach
  /// its state to change tabs. They leave the request here and go home.
  static final ValueNotifier<int> requestedTab = ValueNotifier<int>(0);

  final AppController controller;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  /// The day the home's calendar is showing, so «Создать игру» from the tab
  /// bar opens on it.
  DateTime? _homeDate;

  @override
  void initState() {
    super.initState();
    MainShell.requestedTab.addListener(_takeRequestedTab);
  }

  @override
  void dispose() {
    MainShell.requestedTab.removeListener(_takeRequestedTab);
    super.dispose();
  }

  void _takeRequestedTab() {
    final wanted = MainShell.requestedTab.value;
    if (mounted && wanted != _tab) {
      setState(() => _tab = wanted);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Every tab opens on a field of colour that runs under the status bar,
    // so each screen takes the inset itself and the shell adds none.
    final screens = [
      HomeScreen(
        controller: widget.controller,
        onOpenSearch: () => setState(() => _tab = 1),
        onOpenGames: () => setState(() => _tab = 2),
        onDateChanged: (date) => _homeDate = date,
      ),
      SearchScreen(controller: widget.controller),
      GamesScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller, onLogout: widget.onLogout),
    ];

    return Scaffold(
      // A tab arrives the way a screen does, not with a bare cross-fade.
      body: RiseFadeSwitcher(
        child: KeyedSubtree(key: ValueKey(_tab), child: screens[_tab]),
      ),
      extendBody: true,
      bottomNavigationBar: _BottomNav(
        selectedIndex: _tab,
        onTab: (index) {
          MainShell.requestedTab.value = index;
          setState(() => _tab = index);
        },
        // One screen for a booking and a game; it asks which at the top.
        onCreate: () => context.go(Routes.create(date: _homeDate)),
      ),
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
                        duration: context.motion(
                          const Duration(milliseconds: 320),
                        ),
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
                            icon: AppIcons.home,
                            onTab: onTab,
                          ),
                          _NavItem(
                            index: 1,
                            selectedIndex: selectedIndex,
                            label: context.l10n.navSearch,
                            icon: AppIcons.search,
                            onTab: onTab,
                          ),
                          Expanded(
                            child: Center(
                              child: Semantics(
                                button: true,
                                label: context.l10n.navCreate,
                                child: TapTarget(
                                  key: const ValueKey('create-fab'),
                                  radius: 24,
                                  ringColor: context.colors.onAccent,
                                  onTap: onCreate,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.colors.accent,
                                    ),
                                    child: Icon(
                                      AppIcons.plus,
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
                            icon: AppIcons.volleyball,
                            onTab: onTab,
                          ),
                          _NavItem(
                            index: 3,
                            selectedIndex: selectedIndex,
                            label: context.l10n.navProfile,
                            icon: AppIcons.user,
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
        child: TapTarget(
          key: ValueKey('nav-$label'),
          radius: 18,
          onTap: () => onTab(index),
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
            duration: context.motion(const Duration(milliseconds: 320)),
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
                      // 11, under the 12 of every other label: the tab bar
                      // is a fixed strip, and at 12 «Профиль» lost its end
                      // under a large system font. Apple sets these at 10.
                      style: context.text.labelSmall?.copyWith(
                        color: color,
                        fontSize: 11,
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
