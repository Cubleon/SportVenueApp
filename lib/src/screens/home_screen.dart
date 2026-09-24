import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/sport_ball.dart';
import '../widgets/sport_surface.dart';
import 'booking_screens.dart';
import 'games_screens.dart';
import 'history_screen.dart';

/// The home screen: a date, and everything that date holds.
///
/// It opens on a field of the app's own colour running to the top of the
/// glass, with a two-week calendar on it. The day you pick is what the rest of
/// the page answers to — the clubs row is titled with it and carries how many
/// hours each club still has free that day, and the games below it are the
/// ones being played then. The field fades into the page colour rather than
/// ending at an edge, so the loud top and the calm rest read as one screen.
class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();

  late DateTime _date = DateUtils.dateOnly(widget.controller.now);
  String _sportId = 'all';
  String _query = '';

  /// How many hours each club still has free on [_date], by club id. Empty
  /// until the first answer arrives, and reloaded whenever the day changes.
  Map<String, int> _freeSlots = const {};
  int _slotsToken = 0;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pickDate(DateTime date) {
    if (DateUtils.isSameDay(date, _date)) return;
    setState(() {
      _date = date;
      _freeSlots = const {};
    });
    _loadSlots();
  }

  /// Asks the same endpoint the booking screen asks, for the day on show.
  Future<void> _loadSlots() async {
    final token = ++_slotsToken;
    final day = _date;
    final counts = <String, int>{};
    for (final venue in widget.controller.venues) {
      final slots = await widget.controller.loadSlots(
        venue: venue,
        day: day,
        durationMinutes: 60,
      );
      counts[venue.id] = slots.where((slot) => slot.isAvailable).length;
    }
    if (!mounted || token != _slotsToken) return;
    setState(() => _freeSlots = counts);
  }

  bool _matches(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query);

  List<Venue> get _venues => widget.controller.venues
      .where(
        (venue) =>
            (_sportId == 'all' || venue.sportIds.contains(_sportId)) &&
            (_matches(venue.name) || _matches(venue.address)),
      )
      .toList();

  List<Game> get _games => widget.controller.games
      .where(
        (game) =>
            DateUtils.isSameDay(game.date, _date) &&
            (_sportId == 'all' || game.sportId == _sportId) &&
            (_matches(game.venue.name) || _matches(game.venue.address)),
      )
      .toList();

  String _sportOf(Venue venue) {
    if (_sportId != 'all' && venue.sportIds.contains(_sportId)) {
      return _sportId;
    }
    return venue.sportIds.first;
  }

  void _reset() {
    setState(() {
      _sportId = 'all';
      _query = '';
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final colors = context.colors;
        final venues = _venues;
        final games = _games;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          // The field runs under the status bar in both themes, and it is
          // dark enough for light icons either way.
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: PullToRefresh(
            controller: widget.controller,
            child: CustomScrollView(
              key: const ValueKey('home-screen'),
              // A short list still has to be draggable, or there is nothing
              // to pull.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _SkyHeader(
                    controller: widget.controller,
                    date: _date,
                    onPickDate: _pickDate,
                    search: _search,
                    onQuery: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    onOpenSearch: widget.onOpenSearch,
                    gamesToday: games.length,
                    venuesToday: venues.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(title: context.l10n.sportsSection),
                ),
                SliverToBoxAdapter(
                  child: _CategoryRow(
                    sports: widget.controller.sports,
                    selected: _sportId,
                    onSelect: (id) => setState(() => _sportId = id),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: context.l10n.upcomingBooking,
                    action: context.l10n.seeAll,
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            HistoryScreen(controller: widget.controller),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _Bookings(controller: widget.controller),
                ),
                if (venues.isEmpty)
                  SliverToBoxAdapter(child: _NothingFound(onReset: _reset))
                else ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: context.l10n.freeOnDate(
                        AppFormatters.dateShort(_date),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: context.scaled(248, max: 1.4),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: venues.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final venue = venues[index];
                          return _VenueCard(
                            venue: venue,
                            sportId: _sportOf(venue),
                            freeSlots: _freeSlots[venue.id],
                            // One card wears the page's own colour, the way
                            // the top of the page does.
                            accent: index == 0,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BookingScreen(
                                  controller: widget.controller,
                                  venue: venue,
                                  date: _date,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: context.l10n.openGames,
                      action: context.l10n.seeAll,
                      onAction: widget.onOpenGames,
                    ),
                  ),
                  if (games.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: AppCard(
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: colors.accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.event_available_rounded,
                                  size: 19,
                                  color: colors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  context.l10n.noOpenGames,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                ],
                SliverToBoxAdapter(
                  child: SizedBox(height: context.bottomBarInset),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The field: who you are, when you are playing, and what you are looking
/// for — on the app's own colour, fading into the page rather than ending at
/// an edge.
class _SkyHeader extends StatelessWidget {
  const _SkyHeader({
    required this.controller,
    required this.date,
    required this.onPickDate,
    required this.search,
    required this.onQuery,
    required this.onOpenSearch,
    required this.gamesToday,
    required this.venuesToday,
  });

  final AppController controller;
  final DateTime date;
  final ValueChanged<DateTime> onPickDate;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final VoidCallback onOpenSearch;
  final int gamesToday;
  final int venuesToday;

  static const _days = 14;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final start = DateUtils.dateOnly(controller.now);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.skyTop, colors.skyLow, colors.bg],
          stops: const [0, 0.62, 1],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Two balls break out of the field, which is what keeps it from
          // reading as a coloured rectangle.
          Positioned(
            left: -50,
            top: topInset - 10,
            child: SportBall(
              kind: SportBallKind.soccer,
              size: context.scaled(86, max: 1.15),
            ),
          ),
          Positioned(
            right: -36,
            bottom: -14,
            child: SportBall(
              kind: SportBallKind.basket,
              size: context.scaled(84, max: 1.15),
              tilt: 0.2,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderPill(controller: controller),
                SizedBox(height: context.scaled(22, max: 1.4)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.whenToPlay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        AppFormatters.monthGenitive(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: context.text.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: context.scaled(98, max: 1.45),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _days,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = start.add(Duration(days: index));
                      return _SkyDateCard(
                        key: ValueKey(
                          'home-date-${day.toIso8601String().substring(0, 10)}',
                        ),
                        date: day,
                        selected: DateUtils.isSameDay(day, date),
                        isToday: index == 0,
                        onTap: withSelectionFeedback(() => onPickDate(day)),
                      );
                    },
                  ),
                ),
                SizedBox(height: context.scaled(14, max: 1.3)),
                Text(
                  '${context.l10n.gamesCount(gamesToday)} · '
                  '${context.l10n.clubsNearby(venuesToday)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.scaled(16, max: 1.3)),
                _SearchField(
                  controller: search,
                  onChanged: onQuery,
                  onOpenSearch: onOpenSearch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Container(
            width: context.scaled(42, max: 1.25),
            height: context.scaled(42, max: 1.25),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
            ),
            child: Text(
              controller.greetingName.characters.first.toUpperCase(),
              style: context.text.titleMedium?.copyWith(
                color: colors.onAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: colors.dim,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        context.l10n.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  controller.greetingName.capitalized,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: context.l10n.notifications,
            child: Material(
              color: colors.surfaceRaised,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    showAppSnack(context, context.l10n.noNotifications),
                child: SizedBox(
                  width: context.scaled(42, max: 1.25),
                  height: context.scaled(42, max: 1.25),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One day on the field. The chosen one grows and fills, so the biggest,
/// brightest thing on the screen is the thing everything else answers to.
class _SkyDateCard extends StatelessWidget {
  const _SkyDateCard({
    super.key,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: context.scaled(selected ? 78 : 62, max: 1.3),
          decoration: BoxDecoration(
            color: selected
                ? colors.surface
                : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? colors.surface
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppFormatters.weekdayShort(date),
                style: context.text.labelSmall?.copyWith(
                  color: selected ? colors.muted : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style:
                    (selected
                            ? context.text.headlineSmall
                            : context.text.titleLarge)
                        ?.copyWith(
                          color: selected ? colors.accent : Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
              ),
              if (isToday) ...[
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.accent : Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Types to filter the page; the button beside it opens the map, where a
/// search has room to show where the answers are.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onOpenSearch,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: context.scaled(60, max: 1.4),
      padding: const EdgeInsets.fromLTRB(18, 0, 10, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 21, color: colors.dim),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: colors.accent,
              style: context.text.bodyMedium,
              decoration: InputDecoration.collapsed(
                hintText: context.l10n.searchFieldHint,
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: context.l10n.search,
            child: Material(
              color: colors.accentSoft,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpenSearch,
                child: SizedBox(
                  width: context.scaled(40, max: 1.2),
                  height: context.scaled(40, max: 1.2),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sports, as tiles of their own surfaces. They are the filter — one
/// control, not a decorative row above a second set of chips.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.sports,
    required this.selected,
    required this.onSelect,
  });

  final List<Sport> sports;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.scaled(106, max: 1.5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 8,
            top: -22,
            child: SportBall(
              kind: SportBallKind.tennis,
              size: context.scaled(54, max: 1.15),
              tilt: -0.3,
            ),
          ),
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: sports.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CategoryTile(
                  label: context.l10n.allFilter,
                  selected: selected == 'all',
                  onTap: () => onSelect('all'),
                );
              }
              final sport = sports[index - 1];
              return _CategoryTile(
                label: sport.name.capitalized,
                sportId: sport.id,
                selected: selected == sport.id,
                onTap: () => onSelect(sport.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sportId,
  });

  final String label;
  final String? sportId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = sportId;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: withSelectionFeedback(onTap),
        child: SizedBox(
          width: context.scaled(74, max: 1.35),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: context.scaled(72, max: 1.3),
                height: context.scaled(72, max: 1.3),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: selected ? colors.accentSoft : colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? colors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: id == null
                    ? Icon(Icons.apps_rounded, color: colors.accent)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SportSurface(sportId: id),
                      ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? colors.accent : colors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
            context.l10n.noUpcomingBookings,
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

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.sportId,
    required this.onTap,
    this.accent = false,
    this.freeSlots,
  });

  final Venue venue;
  final String sportId;
  final VoidCallback onTap;

  /// Filled with the accent instead of the card colour. One per row, so the
  /// page's colour appears below the field as well as in it.
  final bool accent;

  /// Free hours on the day the calendar is showing, or null while the answer
  /// is still on its way.
  final int? freeSlots;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = accent ? colors.onAccent : colors.ink;
    final sub = accent ? colors.onAccent.withValues(alpha: 0.78) : colors.muted;

    return SizedBox(
      width: context.scaled(176, max: 1.25),
      child: AppCard(
        onTap: onTap,
        color: accent ? colors.accent : null,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                    height: context.scaled(104, max: 1.15),
                    width: double.infinity,
                    child: SportSurface(sportId: sportId),
                  ),
                ),
                if (freeSlots case final int free)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Badge(
                      background: colors.accent,
                      foreground: colors.onAccent,
                      child: Text(
                        context.l10n.slotsFree(free),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: colors.onAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _Badge(
                    background: colors.surface,
                    foreground: colors.ink,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          venue.rating.toStringAsFixed(1),
                          style: context.text.labelSmall?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      venue.name.capitalized,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.venueAddressDistance(
                      venue.address,
                      venue.distanceKm.toStringAsFixed(1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(color: sub),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.pricePerHour(
                            AppFormatters.money(venue.pricePerHour),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accent ? colors.onAccent : colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 18,
                          color: accent ? colors.accent : colors.onAccent,
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.child,
    required this.background,
    required this.foreground,
  });

  final Widget child;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: child,
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: EmptyState(
        icon: Icons.search_off_rounded,
        title: context.l10n.nothingFound,
        description: context.l10n.noVenuesForSportHint,
        actionLabel: context.l10n.reset,
        onAction: onReset,
      ),
    );
  }
}
