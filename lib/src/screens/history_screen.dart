import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'booking_screens.dart';
import 'games_screens.dart';

/// Everything the player has already committed to: bookings first, then the
/// games they joined.
///
/// Sorted newest first, because a history is read from the top, and the
/// bookings still ahead are the ones a player checks most often.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final bookings = [...controller.bookings]
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
        final games =
            controller.games
                .where(
                  (game) =>
                      game.participants.any((player) => player.isCurrentUser),
                )
                .toList()
              ..sort((a, b) {
                final aStart = DateTime(
                  a.date.year,
                  a.date.month,
                  a.date.day,
                  a.startHour,
                );
                final bStart = DateTime(
                  b.date.year,
                  b.date.month,
                  b.date.day,
                  b.startHour,
                );
                return bStart.compareTo(aStart);
              });

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ScreenTitleBar(
                    title: 'История',
                    subtitle: _summary(bookings.length, games.length),
                    trailing: BackCircleButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                if (bookings.isEmpty && games.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AppCard(
                        child: Text(
                          'Здесь появятся ваши брони и игры',
                          style: context.text.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (bookings.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SectionHeader(title: 'Брони'),
                  ),
                  SliverList.separated(
                    itemCount: bookings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final booking = bookings[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: BookingRow(
                          booking: booking,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookingDetailsScreen(
                                controller: controller,
                                booking: booking,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (games.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader(title: 'Игры')),
                  SliverList.separated(
                    itemCount: games.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _summary(int bookings, int games) {
    final bookingWord = plural(bookings, 'бронь', 'брони', 'броней');
    final gameWord = plural(games, 'игра', 'игры', 'игр');
    return '$bookings $bookingWord · $games $gameWord';
  }
}
