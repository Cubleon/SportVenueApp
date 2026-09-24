import 'package:flutter/material.dart';

import '../labels.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/sky_header.dart';
import '../widgets/sport_ball.dart';
import '../widgets/sport_surface.dart';
import 'player_screen.dart';

/// Stands in for a sport the server sent that this build does not know.
/// Its colour is fixed rather than themed: it is a marker on a map, and a
/// painter draws it where no theme is in reach.
const _fallbackSport = Sport(
  id: 'unknown',
  name: 'Спорт',
  icon: '🏅',
  color: Color(0xFF3D48F5),
);

Sport _sportById(List<Sport> sports, String id) {
  for (final sport in sports) {
    if (sport.id == id) {
      return sport;
    }
  }
  return _fallbackSport;
}

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String _sportId = 'all';
  String _timeFilter = 'evening';

  /// The screen opens on the evening filter, so an empty list is far more
  /// often a filter than an empty city.
  bool get _filtered => _sportId != 'all' || _timeFilter != 'all';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final games = widget.controller.games
            .where((game) => _sportId == 'all' || game.sportId == _sportId)
            .where((game) => _timeFilter == 'all' || game.startHour >= 18)
            .toList();

        return PullToRefresh(
          controller: widget.controller,
          child: CustomScrollView(
            key: const ValueKey('games-screen'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SkyHeader(
                  title: context.l10n.games,
                  eyebrow: AppFormatters.dateFull(widget.controller.now),
                  subtitle: context.l10n.gamesSubtitle,
                  ball: SportBallKind.basket,
                  trailing: SkyIconButton(
                    icon: Icons.tune_rounded,
                    label: context.l10n.filters,
                    onTap: () =>
                        showAppSnack(context, context.l10n.filtersLater),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SportFilter(
                  sports: widget.controller.sports,
                  value: _sportId,
                  onChanged: (id) => setState(() => _sportId = id),
                ),
              ),
              SliverToBoxAdapter(
                child: _TimeFilter(
                  value: _timeFilter,
                  onChanged: (id) => setState(() => _timeFilter = id),
                ),
              ),
              if (games.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _filtered
                        ? EmptyState(
                            key: const ValueKey('games-empty-filtered'),
                            icon: Icons.filter_alt_off_rounded,
                            title: context.l10n.nothingMatchesFilters,
                            description: context.l10n.nothingMatchesFiltersHint,
                            actionLabel: context.l10n.showAllGames,
                            onAction: () => setState(() {
                              _sportId = 'all';
                              _timeFilter = 'all';
                            }),
                          )
                        : EmptyState(
                            key: const ValueKey('games-empty'),
                            icon: Icons.sports_soccer_rounded,
                            title: context.l10n.noOpenGames,
                            description: context.l10n.noOpenGamesHint,
                          ),
                  ),
                ),
              SliverList.builder(
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: MiniGameCard(
                      controller: widget.controller,
                      game: game,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameDetailScreen(
                            controller: widget.controller,
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

/// A game in a list: what it is, when, where, how much, and how many places
/// are left. It does not offer to join — joining is a decision you take after
/// reading who is playing and what the rules are, so the card opens the game
/// and the screen behind it carries the button.
/// A game in a list: what it is, when, where, how much, and how many places
/// are left. It does not offer to join — joining is a decision you take after
/// reading who is playing and what the rules are, so the card opens the game
/// and the screen behind it carries the button.
///
/// The band across the top is the sport's own ground rather than the brand's
/// blue: a pitch is green and ice is blue, so a list of games is told apart
/// at a glance instead of by reading every line.
class MiniGameCard extends StatelessWidget {
  const MiniGameCard({
    super.key,
    required this.controller,
    required this.game,
    required this.onTap,
  });

  final AppController controller;
  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sport = _sportById(controller.sports, game.sportId);
    final countdown = countdownText(context, game.startsAt, controller.now);
    final details = [game.timeRange, ?game.level, ?game.format].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radius - 1),
            ),
            child: SizedBox(
              height: context.scaled(92, max: 1.2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.sportGradient(game.sportId),
                    ),
                  ),
                  Opacity(
                    opacity: 0.35,
                    child: SportSurface(sportId: game.sportId),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _Marker(
                            text:
                                countdown ?? AppFormatters.dateShort(game.date),
                            background: countdown == null
                                ? Colors.black.withValues(alpha: 0.5)
                                : colors.skyLow,
                            foreground: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _Marker(
                            text: game.isFull
                                ? context.l10n.gameFull
                                : context.l10n.freePlaces(game.freePlaces),
                            background: Colors.black.withValues(alpha: 0.5),
                            foreground: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Text(
                      sport.name.capitalized,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.eyebrow(
                        context,
                        Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.venue.name.capitalized,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(
                      child: _AvatarStack(participants: game.participants),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppFormatters.money(game.pricePerPerson),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppTheme.numeric(
                          context.text.headlineSmall,
                        ).copyWith(color: colors.ink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A word stamped on the picture: when it starts, how many places are left.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({
    super.key,
    required this.controller,
    required this.game,
  });

  final AppController controller;
  final Game game;

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  /// Measured, because the bar's button grows with the system font.
  double _barHeight = 128;

  void _onBarHeight(double height) {
    if (mounted && height != _barHeight) {
      setState(() => _barHeight = height);
    }
  }

  bool _joining = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final current = widget.controller.games.firstWhere(
          (item) => item.id == widget.game.id,
          orElse: () => widget.game,
        );
        final sport = _sportById(widget.controller.sports, current.sportId);
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _DetailHeader(
                        title: _gameTypeTitle(context, current.type),
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SportBadge(sport: sport),
                              const SizedBox(height: 12),
                              Text(
                                current.venue.name.capitalized,
                                style: context.text.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                current.venue.address,
                                style: context.text.bodySmall?.copyWith(
                                  color: context.colors.muted,
                                ),
                              ),
                              Divider(height: 28, color: context.colors.border),
                              SummaryRow(
                                label: context.l10n.summaryDate,
                                value: AppFormatters.dateFull(current.date),
                              ),
                              SummaryRow(
                                label: context.l10n.summaryTime,
                                value: current.timeRange,
                              ),
                              SummaryRow(
                                label: context.l10n.price,
                                value: AppFormatters.money(
                                  current.pricePerPerson,
                                ),
                                accent: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionLabel(text: context.l10n.organizer),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: _ParticipantTile(
                          participant: current.organizer,
                          onTap: () => _openPlayer(
                            context,
                            widget.controller,
                            current.organizer,
                            isOrganizer: true,
                          ),
                          trailing: OutlinedButton(
                            onPressed: () =>
                                showAppSnack(context, context.l10n.chatLater),
                            child: Text(context.l10n.write),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionLabel(text: context.l10n.players),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < current.capacity; i++)
                                _PlayerSlot(
                                  participant: i < current.participants.length
                                      ? current.participants[i]
                                      : null,
                                  isLast: i == current.capacity - 1,
                                  onTap: i < current.participants.length
                                      ? () => _openPlayer(
                                          context,
                                          widget.controller,
                                          current.participants[i],
                                        )
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, _barHeight),
                        child: AppCard(
                          borderColor: context.colors.accent.withValues(
                            alpha: 0.2,
                          ),
                          child: SummaryRow(
                            label: context.l10n.price,
                            value: AppFormatters.money(current.pricePerPerson),
                            accent: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  // The button used to float with nothing under it, so the
                  // cards slid through it on the way past.
                  // Someone already in the game is not offered a way in; a
                  // place nobody can give back is a place nobody can take.
                  child: PinnedActionBar(
                    onHeight: _onBarHeight,
                    child:
                        current.participants.any(
                          (player) => player.isCurrentUser,
                        )
                        ? PrimaryButton(
                            key: const ValueKey('detail-leave-game'),
                            label: context.l10n.leaveGame,
                            tone: ButtonTone.neutral,
                            isLoading: _joining,
                            onPressed: _joining ? null : () => _leave(current),
                          )
                        : PrimaryButton(
                            key: const ValueKey('detail-join-game'),
                            label: current.type == GameType.approval
                                ? context.l10n.requestAfterApproval
                                : context.l10n.joinGame,
                            isLoading: _joining,
                            onPressed: current.isFull || _joining
                                ? null
                                : () => _join(current),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _leave(Game game) async {
    final confirmed = await confirmAction(
      context,
      title: context.l10n.leaveGameQuestion,
      message: context.l10n.leaveGameMessage(
        game.venue.name.capitalized,
        AppFormatters.dateShort(game.date),
        game.timeRange,
      ),
      confirmLabel: context.l10n.leaveConfirm,
      cancelLabel: context.l10n.stay,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _joining = true);
    try {
      final left = await widget.controller.leaveGame(game);
      if (!mounted) {
        return;
      }
      showAppSnack(
        context,
        left ? context.l10n.leftGame : context.l10n.wasNotInGame,
        tone: left ? SnackTone.done : SnackTone.plain,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  Future<void> _join(Game game) async {
    setState(() => _joining = true);
    try {
      final joined = await widget.controller.joinGame(game);
      if (!mounted) {
        return;
      }
      showAppSnack(
        context,
        joined ? context.l10n.joined : context.l10n.alreadyJoined,
        // Only a join that took anything is worth a knock.
        tone: joined ? SnackTone.done : SnackTone.plain,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }
}

class _SportFilter extends StatelessWidget {
  const _SportFilter({
    required this.sports,
    required this.value,
    required this.onChanged,
  });

  final List<Sport> sports;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.scaled(46),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          SelectableChip(
            label: context.l10n.allFilter,
            selected: value == 'all',
            onTap: () => onChanged('all'),
          ),
          const SizedBox(width: 8),
          ...sports.map(
            (sport) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SelectableChip(
                label: sport.name.capitalized,
                icon: sport.icon,
                selected: value == sport.id,
                onTap: () => onChanged(sport.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeFilter extends StatelessWidget {
  const _TimeFilter({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = {
      'evening': context.l10n.evening,
      'all': context.l10n.anyDay,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: options.entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: entry.key == 'evening' ? 8 : 0),
              child: SelectableChip(
                label: entry.value,
                selected: value == entry.key,
                onTap: () => onChanged(entry.key),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// The bottom line of a game card: who is in, how many places are left, and
/// the button to take one. Side by side normally; at a large system font the
/// three of them cannot share a line without breaking words mid-syllable, so
/// the button drops underneath and spans the card.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.participants});

  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 30,
      child: Stack(
        children: [
          for (var i = 0; i < participants.take(3).length; i++)
            Positioned(
              left: i * 22,
              child: _Avatar(participant: participants[i], size: 30),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.participant, this.size = 42});

  final Participant participant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: participant.isCurrentUser
            ? context.colors.accent
            : context.colors.surfaceRaised,
        border: Border.all(color: context.colors.bg, width: 2),
      ),
      child: Center(
        child: Text(
          participant.initial,
          style: context.text.labelLarge?.copyWith(
            color: participant.isCurrentUser
                ? context.colors.onAccent
                : context.colors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: context.l10n.back,
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.ink,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    this.trailing,
    this.onTap,
  });

  final Participant participant;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          _Avatar(participant: participant, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.name,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  participant.hasRating
                      ? context.l10n.rating(
                          participant.rating.toStringAsFixed(1),
                        )
                      : context.l10n.playerOrganizer,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({
    required this.participant,
    required this.isLast,
    this.onTap,
  });

  final Participant? participant;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final empty = participant == null;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusInner),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                if (empty)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.ink.withValues(alpha: 0.36),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                  )
                else
                  _Avatar(participant: participant!, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    empty ? context.l10n.freeSlot : participant!.name,
                    style: context.text.bodyMedium?.copyWith(
                      color: empty ? context.colors.dim : context.colors.ink,
                      fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!empty && participant!.hasRating)
                  Text(
                    participant!.rating.toStringAsFixed(1),
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: context.colors.border),
      ],
    );
  }
}

/// Opens a player, so a roster reads as people rather than as a list of
/// names that does nothing when tapped.
void _openPlayer(
  BuildContext context,
  AppController controller,
  Participant player, {
  bool isOrganizer = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerScreen(
        controller: controller,
        player: player,
        isOrganizer: isOrganizer,
      ),
    ),
  );
}

String _gameTypeTitle(BuildContext context, GameType type) {
  return switch (type) {
    GameType.open => context.l10n.openGame,
    GameType.approval => context.l10n.approvalGame,
    GameType.closed => context.l10n.closedGame,
  };
}
