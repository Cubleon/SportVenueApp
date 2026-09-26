import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_icons.dart';

import '../labels.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
import '../router.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/sky_header.dart';
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

  /// Everything, until the reader narrows it.
  ///
  /// This opened on «Вечер», which is a filter the reader did not set and
  /// cannot see the effect of: games in the morning simply were not there,
  /// and the screen looked like a city with nothing going on.
  String _timeFilter = 'all';

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
                            icon: AppIcons.filterX,
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
                            icon: AppIcons.volleyball,
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
                      onTap: () => context.go(gameLocation(game)),
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

    return Pressable(
      child: AppCard(
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
                                  countdown ??
                                  AppFormatters.dateShort(game.date),
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
                    style: context.text.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Flexible(
                        child: _AvatarStack(
                          participants: game.participants,
                          capacity: game.capacity,
                        ),
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
                        title: context.l10n.game,
                        onBack: () => Navigator.of(context).pop(),
                        onShare: canShareLinks
                            ? () => copyLink(context, gameLocation(current))
                            : null,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SportBadge(sport: sport),
                                  if (current.type != GameType.open) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _gameTypeTitle(context, current.type),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.eyebrow(
                                          context,
                                          context.colors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
                                label: context.l10n.playersStep,
                                value: context.l10n.playersOfCapacity(
                                  current.participants.length,
                                  current.capacity,
                                ),
                              ),
                              if (current.level case final String level)
                                SummaryRow(
                                  label: context.l10n.gameLevel,
                                  value: level,
                                ),
                              if (current.format case final String format)
                                SummaryRow(
                                  label: context.l10n.gameFormat,
                                  value: format,
                                ),
                              SummaryRow(
                                label: context.l10n.pricePerPerson,
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
                    // The same price was printed twice on one screen, seven
                    // hundred pixels apart. The card above says it; this
                    // leaves only the room the pinned bar needs.
                    SliverToBoxAdapter(child: SizedBox(height: _barHeight)),
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
                                ? context.l10n.sendRequest
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
      // A game «по одобрению» used to promise a request and then put the
      // reader straight into the roster. Rather than trusting either story,
      // this reads the game back: in the list of players means joined, and
      // anything else means the request is with the organiser.
      final after = widget.controller.games.firstWhere(
        (item) => item.id == game.id,
        orElse: () => game,
      );
      final inside = after.participants.any((p) => p.isCurrentUser);
      showAppSnack(
        context,
        !joined
            ? context.l10n.alreadyJoined
            : inside
            ? context.l10n.joined
            : context.l10n.requestSent,
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
                selected: value == sport.id,
                color: AppTheme.sportGround(sport.id).last,
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
      'all': context.l10n.anyTime,
      'evening': context.l10n.evening,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: options.entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: entry.key == 'all' ? 8 : 0),
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
/// Who is in, and how many places are still open — a filled circle for each
/// player, a hollow one for each place nobody has taken.
///
/// Laid out in a row with air between the circles rather than overlapped like
/// a stack of faces: the point here is counting, and three filled beside
/// three hollow only counts at a glance if the circles are separate.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.participants, required this.capacity});

  final List<Participant> participants;
  final int capacity;

  /// Past this many, circles stop being countable and become a texture, so
  /// the remainder is written as a number instead.
  static const _maxCircles = 8;

  @override
  Widget build(BuildContext context) {
    final taken = participants.length;
    final circles = capacity.clamp(taken, _maxCircles);
    final hidden = capacity - circles;
    final size = context.scaled(26, max: 1.2);

    // Eight seats and a price do not always fit a narrow card, and a row that
    // overflows is worse than one drawn a little smaller.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < circles; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            i < taken
                ? _Avatar(participant: participants[i], size: size)
                : _EmptySeat(size: size),
          ],
          if (hidden > 0) ...[
            const SizedBox(width: 6),
            Text(
              '+$hidden',
              style: AppTheme.numeric(context.text.labelSmall).copyWith(
                color: context.colors.dim,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A place nobody has taken: the same circle, drawn as an outline.
class _EmptySeat extends StatelessWidget {
  const _EmptySeat({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.bgAlt,
        // At full strength the ring carries 3.5:1 against the card in light
        // and 4.5:1 in dark — an outline is a shape, and a shape has to
        // clear 3:1 to be seen at all.
        border: Border.all(color: context.colors.dim, width: 2),
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
        // Taken seats are tinted and their initials carry the accent: grey on
        // a grey disc was there, but only just, and a seat is meant to be
        // countable across the room.
        color: participant.isCurrentUser
            ? context.colors.accent
            : context.colors.accentSoft,
      ),
      child: Center(
        child: Text(
          participant.initial,
          style: context.text.labelLarge?.copyWith(
            color: participant.isCurrentUser
                ? context.colors.onAccent
                : context.colors.accent,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    required this.onBack,
    this.onShare,
  });

  final String title;
  final VoidCallback onBack;

  /// Offered where there is an address to offer. Getting people into a
  /// pickup game means sending them to it, and until the app had routes
  /// there was nothing to send.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: context.l10n.back,
            onPressed: onBack,
            icon: const Icon(AppIcons.chevronLeft),
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
          if (onShare == null)
            const SizedBox(width: 48)
          else
            IconButton.filled(
              key: const ValueKey('share-game'),
              tooltip: context.l10n.shareGame,
              onPressed: onShare,
              icon: const Icon(AppIcons.share),
              style: IconButton.styleFrom(
                backgroundColor: context.colors.surface,
                foregroundColor: context.colors.ink,
              ),
            ),
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
  const _ParticipantTile({required this.participant, this.onTap});

  final Participant participant;
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
          // A card that opens someone's profile says so, now that the
          // button which used to sit here has gone.
          if (onTap != null)
            Icon(AppIcons.chevronRight, size: 18, color: context.colors.dim),
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
                  const _EmptySeat(size: 40)
                else
                  _Avatar(participant: participant!, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    empty ? context.l10n.freeSlot : participant!.name,
                    style: empty
                        ? context.text.bodyMedium?.copyWith(
                            color: context.colors.dim,
                            fontStyle: FontStyle.italic,
                          )
                        : context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                ),
                if (!empty && participant!.hasRating)
                  Text(
                    participant!.rating.toStringAsFixed(1),
                    style: AppTheme.numeric(context.text.labelLarge).copyWith(
                      color: context.colors.muted,
                      fontWeight: FontWeight.w700,
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
