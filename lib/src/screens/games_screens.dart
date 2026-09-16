import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

const _fallbackSport = Sport(
  id: 'unknown',
  name: 'Спорт',
  icon: '🏅',
  color: AppColors.accent,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final games = widget.controller.games
            .where((game) => _sportId == 'all' || game.sportId == _sportId)
            .where((game) => _timeFilter == 'all' || game.startHour >= 18)
            .toList();

        return CustomScrollView(
          key: const ValueKey('games-screen'),
          slivers: [
            SliverToBoxAdapter(
              child: ScreenTitleBar(
                title: 'Игры',
                subtitle: 'pickup-матчи рядом',
                trailing: IconButton(
                  onPressed: () => showAppSnack(
                    context,
                    'Расширенные фильтры появятся позже',
                  ),
                  icon: const Icon(Icons.tune_rounded),
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
            const SliverToBoxAdapter(child: SizedBox(height: 118)),
          ],
        );
      },
    );
  }
}

class MiniGameCard extends StatefulWidget {
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
  State<MiniGameCard> createState() => _MiniGameCardState();
}

class _MiniGameCardState extends State<MiniGameCard> {
  bool _joining = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final game = widget.game;
    final sport = _sportById(controller.sports, game.sportId);
    return AppCard(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SportBadge(sport: sport, compact: true),
              const Spacer(),
              Text(
                AppFormatters.money(game.pricePerPerson),
                style: context.text.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            game.venue.name.capitalized,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${AppFormatters.dateShort(game.date)} · ${game.timeRange}',
            style: context.text.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AvatarStack(participants: game.participants),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${game.freePlaces} ${game.freePlaces == 1 ? 'место' : 'места'} свободно',
                  style: context.text.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton(
                  key: ValueKey('join-${game.id}'),
                  onPressed: game.isFull || _joining ? null : _join,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.surfaceRaised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onAccent,
                          ),
                        )
                      : Text(
                          'Вступить',
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.onAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final joined = await widget.controller.joinGame(widget.game);
      if (!mounted) {
        return;
      }
      showAppSnack(
        context,
        joined ? 'Вы присоединились к игре' : 'Вы уже в этой игре',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, widget.controller.messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
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
                        title: _gameTypeTitle(current.type),
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
                                  color: AppColors.muted,
                                ),
                              ),
                              const Divider(
                                height: 28,
                                color: AppColors.border,
                              ),
                              SummaryRow(
                                label: 'Дата',
                                value: AppFormatters.dateFull(current.date),
                              ),
                              SummaryRow(
                                label: 'Время',
                                value: current.timeRange,
                              ),
                              SummaryRow(
                                label: 'Стоимость',
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
                      child: _SectionLabel(text: 'Организатор'),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: _ParticipantTile(
                          participant: current.organizer,
                          trailing: OutlinedButton(
                            onPressed: () =>
                                showAppSnack(context, 'Чат подключится позже'),
                            child: const Text('Написать'),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _SectionLabel(text: 'игроки')),
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
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 128),
                        child: AppCard(
                          borderColor: AppColors.accent.withValues(alpha: 0.2),
                          child: SummaryRow(
                            label: 'Стоимость',
                            value: AppFormatters.money(current.pricePerPerson),
                            accent: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 28,
                  child: PrimaryButton(
                    key: const ValueKey('detail-join-game'),
                    label: current.type == GameType.approval
                        ? 'Заявка и оплата после одобрения'
                        : 'Присоединиться к игре',
                    isLoading: _joining,
                    onPressed: current.isFull || _joining
                        ? null
                        : () => _join(current),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        joined ? 'Вы присоединились к игре' : 'Вы уже в этой игре',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, widget.controller.messageFor(error));
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
      height: 46,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          SelectableChip(
            label: 'Все',
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
    final options = {'evening': 'Вечер', 'all': 'Любой день'};
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
            ? AppColors.accent
            : AppColors.surfaceRaised,
        border: Border.all(color: AppColors.bg, width: 2),
      ),
      child: Center(
        child: Text(
          participant.initial,
          style: context.text.labelLarge?.copyWith(
            color: participant.isCurrentUser
                ? AppColors.onAccent
                : AppColors.muted,
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
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.ink,
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
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, this.trailing});

  final Participant participant;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                  'Рейтинг ${participant.rating.toStringAsFixed(1)}',
                  style: context.text.bodySmall?.copyWith(color: AppColors.muted),
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
  const _PlayerSlot({required this.participant, required this.isLast});

  final Participant? participant;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final empty = participant == null;
    return Column(
      children: [
        Padding(
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
                      color: AppColors.ink.withValues(alpha: 0.36),
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
                  empty ? 'свободно' : participant!.name,
                  style: context.text.bodyMedium?.copyWith(
                    color: empty ? AppColors.dim : AppColors.ink,
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!empty)
                Text(
                  participant!.rating.toStringAsFixed(1),
                  style: context.text.bodySmall?.copyWith(color: AppColors.muted),
                ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

String _gameTypeTitle(GameType type) {
  return switch (type) {
    GameType.open => 'Открытая игра',
    GameType.approval => 'Игра по одобрению',
    GameType.closed => 'Закрытая игра',
  };
}
