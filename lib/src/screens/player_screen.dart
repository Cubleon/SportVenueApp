import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'games_screens.dart';

/// Who someone is, as far as this app knows.
///
/// A roster used to be a list of names that did nothing when tapped: a
/// player could see who else was in their game and nothing about them. What
/// is here is what the game itself carries — the name, the rating, whether
/// they organise it — plus the other games they are in, which is the thing
/// worth knowing before joining a stranger's football.
///
/// It is not fetched: there is no endpoint for another person's profile, so
/// this reads what the app already holds rather than pretending to more.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    super.key,
    required this.controller,
    required this.player,
    this.isOrganizer = false,
  });

  final AppController controller;
  final Participant player;
  final bool isOrganizer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final games = controller.games
            .where(
              (game) =>
                  game.organizer.sameAs(player) ||
                  game.participants.any((other) => other.sameAs(player)),
            )
            .toList();

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ScreenTitleBar(
                    title: context.l10n.player,
                    leading: BackCircleButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: context.scaled(62),
                            height: context.scaled(62),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.accent,
                            ),
                            child: Text(
                              player.initial,
                              style: context.text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.colors.onAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.name,
                                  style: context.text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _subtitle(context),
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
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(title: context.l10n.playerGames),
                ),
                if (games.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AppCard(
                        child: Text(
                          context.l10n.playerNoGames,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.muted,
                          ),
                        ),
                      ),
                    ),
                  )
                else
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
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The one line under the name: what they are here, and how they are
  /// rated — but only when there is a rating. Every player the server sends
  /// arrives rated zero, and "Рейтинг 0.0" reads as a bad player rather
  /// than an unrated one.
  String _subtitle(BuildContext context) {
    final parts = <String>[
      if (isOrganizer) context.l10n.playerOrganizer,
      if (player.status == 'pending') context.l10n.playerPending,
      if (player.hasRating)
        context.l10n.rating(player.rating.toStringAsFixed(1)),
    ];
    return parts.isEmpty ? context.l10n.player : parts.join(' · ');
  }
}
