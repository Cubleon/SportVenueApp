import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'booking_screens.dart';
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
        return CustomScrollView(
          key: const ValueKey('home-screen'),
          slivers: [
            SliverToBoxAdapter(child: _TopBar(controller: controller)),
            SliverToBoxAdapter(child: _SearchBar(onTap: onOpenSearch)),
            SliverToBoxAdapter(child: _Sports(controller: controller)),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Предстоящая бронь',
                action: 'Все',
                onAction: () =>
                    showAppSnack(context, 'История броней откроется в профиле'),
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
            const SliverToBoxAdapter(child: SizedBox(height: 118)),
          ],
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
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Москва',
                      style: context.text.bodySmall?.copyWith(
                        color: AppColors.dim,
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
            const Icon(Icons.search_rounded, color: AppColors.dim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Найти площадку или игру',
                style: context.text.bodyMedium?.copyWith(color: AppColors.dim),
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
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final sport = controller.selectedSports[index];
          return SelectableChip(
            label: sport.name.capitalized,
            icon: sport.icon,
            selected: true,
            color: sport.color,
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
            style: context.text.bodyMedium?.copyWith(color: AppColors.dim),
          ),
        ),
      );
    }

    final booking = upcomingBookings.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        key: ValueKey('upcoming-booking-${booking.id}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                BookingDetailsScreen(controller: controller, booking: booking),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppFormatters.weekdayShort(
                      booking.draft.date,
                    ).toUpperCase(),
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${booking.draft.date.day}',
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.draft.venue.name.capitalized,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking.draft.timeRange} · ${booking.status}',
                    style: context.text.bodySmall?.copyWith(
                      color: AppColors.dim,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.dim),
          ],
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
      height: 232,
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
                  VenueHero(venue: venue, height: 120),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              venue.rating.toStringAsFixed(1),
                              style: context.text.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${AppFormatters.money(venue.pricePerHour)}/час',
                              style: context.text.labelLarge?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w900,
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
                            color: AppColors.dim,
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
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.white),
        ),
      ),
    );
  }
}
