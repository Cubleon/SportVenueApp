import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
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
    final screens = [
      HomeScreen(
        controller: widget.controller,
        onOpenSearch: () => setState(() => _tab = 1),
        onOpenGames: () => setState(() => _tab = 2),
      ),
      SearchScreen(controller: widget.controller),
      GamesScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_tab), child: screens[_tab]),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _BottomNav(
        selectedIndex: _tab,
        onTab: (index) => setState(() => _tab = index),
        onCreate: _showCreateSheet,
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
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
                      color: AppColors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'создать',
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _SheetAction(
                  icon: Icons.sports_soccer_rounded,
                  title: 'создать игру',
                  subtitle: 'соберите участников и оплатите долю',
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
                  title: 'забронировать площадку',
                  subtitle: 'быстрый выбор слота в первом клубе',
                  onTap: () {
                    final venues = widget.controller.preferredVenues.isNotEmpty
                        ? widget.controller.preferredVenues
                        : widget.controller.venues;
                    Navigator.pop(sheetContext);
                    if (venues.isEmpty) {
                      showAppSnack(context, 'доступных площадок пока нет');
                      return;
                    }
                    final venue = venues[0];
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(
                          controller: widget.controller,
                          venue: venue,
                        ),
                      ),
                    );
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

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onTab,
    required this.onCreate,
  });

  final int selectedIndex;
  final ValueChanged<int> onTab;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(color: AppColors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(
              index: 0,
              selectedIndex: selectedIndex,
              label: 'главная',
              icon: Icons.home_rounded,
              onTab: onTab,
            ),
            _NavItem(
              index: 1,
              selectedIndex: selectedIndex,
              label: 'поиск',
              icon: Icons.search_rounded,
              onTab: onTab,
            ),
            Expanded(
              child: GestureDetector(
                key: const ValueKey('create-fab'),
                onTap: onCreate,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      margin: const EdgeInsets.only(top: 0, bottom: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentPressed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: AppColors.bg, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.48),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            _NavItem(
              index: 2,
              selectedIndex: selectedIndex,
              label: 'игры',
              icon: Icons.sports_soccer_rounded,
              onTab: onTab,
            ),
            _NavItem(
              index: 3,
              selectedIndex: selectedIndex,
              label: 'профиль',
              icon: Icons.person_rounded,
              onTab: onTab,
            ),
          ],
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
    final color = selected
        ? AppColors.accent
        : AppColors.white.withValues(alpha: 0.48);
    return Expanded(
      child: InkWell(
        key: ValueKey('nav-$label'),
        onTap: () => onTab(index),
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(color: AppColors.dim),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.dim),
        ],
      ),
    );
  }
}
