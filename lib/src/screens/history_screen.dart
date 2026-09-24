import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
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
            child: PullToRefresh(
              controller: controller,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenTitleBar(
                      title: context.l10n.history,
                      subtitle: context.l10n.historySummary(
                        bookings.length,
                        games.length,
                      ),
                      leading: BackCircleButton(
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
                            context.l10n.historyEmpty,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (bookings.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: SectionHeader(title: context.l10n.bookingsSection),
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
                    SliverToBoxAdapter(
                      child: SectionHeader(title: context.l10n.gamesSection),
                    ),
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
          ),
        );
      },
    );
  }
}
