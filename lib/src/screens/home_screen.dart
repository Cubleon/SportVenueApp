import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/shared_widgets.dart';
import 'booking_screens.dart';
import 'history_screen.dart';
import 'games_screens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenSearch,
    required this.onOpenGames,
  });

  final AppController controller;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenGames;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return PullToRefresh(
          controller: controller,
          child: CustomScrollView(
            key: const ValueKey('home-screen'),
            // A short list still has to be draggable, or there is nothing
            // to pull.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _TopBar(controller: controller)),
              SliverToBoxAdapter(child: _SearchBar(onTap: onOpenSearch)),
              SliverToBoxAdapter(child: _Sports(controller: controller)),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Предстоящая бронь',
                  action: 'Все',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistoryScreen(controller: controller),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _Bookings(controller: controller)),
              SliverToBoxAdapter(
                child: SectionHeader(title: 'Рекомендованные площадки'),
              ),
              SliverToBoxAdapter(child: _Venues(controller: controller)),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Открытые игры',
                  action: 'Все',
                  onAction: onOpenGames,
                ),
              ),
              SliverList.builder(
                itemCount: controller.preferredGames.take(2).length,
                itemBuilder: (context, index) {
                  final game = controller.preferredGames[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: MiniGameCard(
                      controller: controller,
                      game: game,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameDetailScreen(
                            controller: controller,
                            game: game,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: context.bottomBarInset),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Привет, ${controller.greetingName.capitalized}',
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Москва',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _RoundIcon(
            icon: Icons.notifications_none_rounded,
            label: 'Уведомления',
            onTap: () => showAppSnack(context, 'Уведомлений пока нет'),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: context.colors.dim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Найти площадку или игру',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sports extends StatelessWidget {
  const _Sports({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.scaled(46),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final sport = controller.selectedSports[index];
          return SelectableChip(
            label: sport.name.capitalized,
            icon: sport.icon,
            selected: true,
            onTap: () => controller.togglePreferredSport(sport.id),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: controller.selectedSports.length,
      ),
    );
  }
}

class _Bookings extends StatelessWidget {
  const _Bookings({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final upcomingBookings = controller.upcomingBookings;
    if (upcomingBookings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppCard(
          child: Text(
            'У вас пока нет предстоящих броней',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.muted,
            ),
          ),
        ),
      );
    }

    final booking = upcomingBookings.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: BookingRow(
        booking: booking,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                BookingDetailsScreen(controller: controller, booking: booking),
          ),
        ),
      ),
    );
  }
}

class _Venues extends StatelessWidget {
  const _Venues({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final venues = controller.preferredVenues;
    return SizedBox(
      height: context.scaled(292),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: venues.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final venue = venues[index];
          return SizedBox(
            width: 276,
            child: AppCard(
              padding: EdgeInsets.zero,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      BookingScreen(controller: controller, venue: venue),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: VenueHero(venue: venue, height: 116),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.name.capitalized,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${venue.address} · ${venue.distanceKm.toStringAsFixed(1)} км',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: context.colors.ink,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              venue.rating.toStringAsFixed(1),
                              style: context.text.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${AppFormatters.money(venue.pricePerHour)}/час',
                              style: context.text.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          venue.description.capitalized,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;

  /// Spoken by a screen reader, which has no icon to look at.
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.colors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: context.colors.ink, size: 22),
          ),
        ),
      ),
    );
  }
}
