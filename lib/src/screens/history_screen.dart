import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../theme/app_icons.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/shared_widgets.dart';
import 'booking_screens.dart';
import 'games_screens.dart';

/// Which half of a player's history a screen opens on.
enum HistoryFocus {
  /// Both, bookings first. The profile's own history row.
  all,

  /// Only what they have booked.
  bookings,

  /// Only the games they joined.
  games,
}

/// Everything the player has already committed to: bookings first, then the
/// games they joined.
///
/// Sorted newest first, because a history is read from the top, and the
/// bookings still ahead are the ones a player checks most often.
///
/// The home screen opens it on one half at a time — "мои брони" and "мои
/// игры" are two different questions, and a reader who asked one of them
/// should not have to scroll past the other.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.controller,
    this.focus = HistoryFocus.all,
    this.onFindGames,
  });

  final AppController controller;
  final HistoryFocus focus;

  /// Where an empty list can send the reader. Without it this screen is a
  /// dead end: a sentence saying there is nothing, and the back button.
  final VoidCallback? onFindGames;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final bookings = [...controller.bookings]
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
        final active = bookings.where((booking) => booking.isActive).length;
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

        final showBookings = focus != HistoryFocus.games;
        final showGames = focus != HistoryFocus.bookings;
        final title = switch (focus) {
          HistoryFocus.all => context.l10n.history,
          HistoryFocus.bookings => context.l10n.myBookings,
          HistoryFocus.games => context.l10n.myGames,
        };
        final subtitle = switch (focus) {
          // The rows still show what was cancelled — that is what a history
          // is for — but the count above them is of bookings still standing.
          HistoryFocus.all => context.l10n.historySummary(active, games.length),
          HistoryFocus.bookings => context.l10n.bookingsCount(active),
          HistoryFocus.games => context.l10n.gamesCount(games.length),
        };

        return Scaffold(
          body: SafeArea(
            child: PullToRefresh(
              controller: controller,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenTitleBar(
                      title: title,
                      subtitle: subtitle,
                      leading: BackCircleButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  if ((!showBookings || bookings.isEmpty) &&
                      (!showGames || games.isEmpty))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        // The same empty state the games list uses: a mark,
                        // a reason, and somewhere to go.
                        child: EmptyState(
                          key: const ValueKey('history-empty'),
                          icon: focus == HistoryFocus.games
                              ? AppIcons.volleyball
                              : AppIcons.calendarCheck,
                          title: switch (focus) {
                            HistoryFocus.all => context.l10n.historyEmptyTitle,
                            HistoryFocus.bookings =>
                              context.l10n.noBookingsTitle,
                            HistoryFocus.games => context.l10n.noGamesTitle,
                          },
                          description: switch (focus) {
                            HistoryFocus.all => context.l10n.historyEmpty,
                            HistoryFocus.bookings =>
                              context.l10n.noUpcomingBookings,
                            HistoryFocus.games => context.l10n.noMyGames,
                          },
                          actionLabel: onFindGames == null
                              ? null
                              : context.l10n.findGame,
                          onAction: onFindGames == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  onFindGames!();
                                },
                        ),
                      ),
                    ),
                  if (showBookings && bookings.isNotEmpty) ...[
                    if (focus == HistoryFocus.all)
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          title: context.l10n.bookingsSection,
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 4)),
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
                  if (showGames && games.isNotEmpty) ...[
                    if (focus == HistoryFocus.all)
                      SliverToBoxAdapter(
                        child: SectionHeader(title: context.l10n.gamesSection),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 4)),
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
