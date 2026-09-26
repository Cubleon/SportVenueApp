import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_icons.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
import '../router.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeleton.dart';
import '../widgets/sport_surface.dart';

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

  /// How many bookings existed last time the free hours were counted.
  ///
  /// Coming back from a booking, the hours this club has left are one fewer
  /// than the chip says. Watching the data rather than the navigation catches
  /// it wherever the booking was made — the club list, the map, the tab bar.
  int _bookingsSeen = 0;

  @override
  void initState() {
    super.initState();
    _bookingsSeen = widget.controller.bookings.length;
    widget.controller.addListener(_watchBookings);
    _loadSlots();
  }

  void _watchBookings() {
    final now = widget.controller.bookings.length;
    if (now != _bookingsSeen) {
      _bookingsSeen = now;
      _loadSlots();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_watchBookings);
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
            also: _loadSlots,
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
                  child: _MineRow(
                    controller: widget.controller,
                    onBookings: () => context.go(Routes.bookings),
                    onGames: () => context.go(Routes.myGames),
                  ),
                ),
                if (venues.isEmpty)
                  SliverToBoxAdapter(
                    child: _NothingFound(query: _query, onReset: _reset),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: context.l10n.freeOnDate(
                        AppFormatters.dateShort(_date),
                      ),
                    ),
                  ),
                  // A list, not a carousel: three clubs read in less room
                  // than one and a half cards did, and nothing is hidden
                  // off the right edge.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        child: ColoredBox(
                          color: colors.surface,
                          child: Column(
                            children: [
                              for (final (index, venue) in venues.indexed)
                                _VenueRow(
                                  venue: venue,
                                  sportId: _sportOf(venue),
                                  freeSlots: _freeSlots[venue.id],
                                  divided: index > 0,
                                  onTap: () => context.go(
                                    Routes.venue(venue.id, date: _date),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
class _SkyHeader extends StatefulWidget {
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

  @override
  State<_SkyHeader> createState() => _SkyHeaderState();
}

class _SkyHeaderState extends State<_SkyHeader> {
  static const _days = 14;
  static const _cardExtent = 70.0;

  final ScrollController _strip = ScrollController();

  @override
  void didUpdateWidget(_SkyHeader old) {
    super.didUpdateWidget(old);
    if (!DateUtils.isSameDay(old.date, widget.date)) {
      _bringIntoView();
    }
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  /// Slides the chosen day towards the left edge rather than leaving it
  /// wherever the finger happened to land. Picking a day at the far right
  /// otherwise hides the week that follows it, which is the week you are
  /// about to look at.
  void _bringIntoView() {
    if (!_strip.hasClients) return;
    final start = DateUtils.dateOnly(widget.controller.now);
    final index = widget.date.difference(start).inDays;
    final target = (index - 1) * _cardExtent;
    _strip.animateTo(
      target.clamp(0, _strip.position.maxScrollExtent),
      duration: context.motion(const Duration(milliseconds: 280)),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final date = widget.date;
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
                    controller: _strip,
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
                        onTap: withSelectionFeedback(
                          () => widget.onPickDate(day),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: context.scaled(14, max: 1.3)),
                Text(
                  '${context.l10n.gamesCount(widget.gamesToday)} · '
                  '${context.l10n.clubsNearby(widget.venuesToday)}',
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
                  controller: widget.search,
                  onChanged: widget.onQuery,
                  onOpenSearch: widget.onOpenSearch,
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
                    Icon(AppIcons.mapPin, size: 13, color: colors.dim),
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
                  child: Icon(AppIcons.bell, size: 20, color: colors.ink),
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
      child: TapTarget(
        onTap: onTap,
        radius: 22,
        ringColor: Colors.white,
        child: AnimatedContainer(
          duration: context.motion(const Duration(milliseconds: 180)),
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
          Icon(AppIcons.search, size: 21, color: colors.dim),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: colors.accent,
              style: context.text.bodyMedium,
              textInputAction: TextInputAction.search,
              // Spelled out rather than collapsed: a collapsed decoration
              // still inherits the theme's focused outline, and this field
              // already has a shape of its own — the pill it sits in.
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: context.l10n.searchFieldHint,
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: context.l10n.openMap,
            child: Tooltip(
              message: context.l10n.openMap,
              child: Material(
                color: colors.accentSoft,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenSearch,
                  child: SizedBox(
                    width: context.scaled(44, max: 1.2),
                    height: context.scaled(44, max: 1.2),
                    // Sliders mean filters in every app of this kind, and
                    // this button opens the map. The app has no filters to
                    // open yet, so the icon follows the action instead of
                    // promising one that isn't there.
                    child: Icon(
                      AppIcons.mapPin,
                      size: 19,
                      color: colors.accent,
                    ),
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
      child: ListView.separated(
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
      child: TapTarget(
        onTap: withSelectionFeedback(onTap),
        radius: 20,
        child: SizedBox(
          width: context.scaled(74, max: 1.35),
          child: Column(
            children: [
              // The ground fills the tile, corner to corner. Inset inside a
              // white frame it read as an icon of a pitch; at full bleed it
              // reads as the pitch.
              AnimatedContainer(
                duration: context.motion(const Duration(milliseconds: 180)),
                width: context.scaled(72, max: 1.3),
                height: context.scaled(72, max: 1.3),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    // The ring is the sport's own colour, so choosing hockey
                    // and choosing tennis do not look like the same act.
                    color: selected
                        ? (id == null
                              ? colors.accent
                              : AppTheme.sportGround(id).last)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: id == null
                    ? Icon(AppIcons.layoutGrid, color: colors.accent)
                    : SportSurface(sportId: id),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: selected
                      ? (id == null
                            ? colors.accent
                            : AppTheme.sportGround(id).last)
                      : colors.muted,
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

class _MineRow extends StatelessWidget {
  const _MineRow({
    required this.controller,
    required this.onBookings,
    required this.onGames,
  });

  final AppController controller;
  final VoidCallback onBookings;
  final VoidCallback onGames;

  @override
  Widget build(BuildContext context) {
    final mine = controller.games
        .where(
          (game) => game.participants.any((player) => player.isCurrentUser),
        )
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _MineCard(
              icon: AppIcons.calendarCheck,
              count: controller.activeBookings.length,
              label: context.l10n.myBookings,
              onTap: onBookings,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MineCard(
              icon: AppIcons.volleyball,
              count: mine,
              label: context.l10n.myGames,
              onTap: onGames,
            ),
          ),
        ],
      ),
    );
  }
}

class _MineCard extends StatelessWidget {
  const _MineCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colors.accent),
                const Spacer(),
                Icon(AppIcons.chevronRight, size: 16, color: colors.dim),
              ],
            ),
            SizedBox(height: context.scaled(14, max: 1.3)),
            Text(
              '$count',
              style: AppTheme.numeric(
                context.text.headlineMedium,
              ).copyWith(color: colors.ink),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({
    required this.venue,
    required this.sportId,
    required this.onTap,
    required this.divided,
    this.freeSlots,
  });

  final Venue venue;
  final String sportId;
  final VoidCallback onTap;

  /// Every row but the first carries a hairline. A list held together by one
  /// surface reads denser than the same rows as separate cards.
  final bool divided;

  /// Free hours on the day the calendar is showing, or null while the answer
  /// is still on its way.
  final int? freeSlots;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final free = freeSlots;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            border: divided
                ? Border(top: BorderSide(color: colors.border))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: venueHeroTag(venue),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: context.scaled(56, max: 1.2),
                    height: context.scaled(56, max: 1.2),
                    child: SportSurface(sportId: sportId),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name.capitalized,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // Walking time is only worth saying while walking is
                      // plausible; past that it is a distance, and how you
                      // get there is your business.
                      venue.distanceKm <= 2.5
                          ? '${venue.address} · '
                                '${context.l10n.walkMinutes(AppFormatters.walkMinutes(venue.distanceKm))}'
                          : context.l10n.venueAddressDistance(
                              venue.address,
                              venue.distanceKm.toStringAsFixed(1),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // What is free today comes first: it is the one fact
                        // that changes with the calendar above. Until it
                        // lands it holds its own space, so the row does not
                        // jump when it does.
                        if (free != null)
                          _Tag(
                            label: context.l10n.freeHoursToday(free),
                            tone: _TagTone.live,
                          )
                        else
                          const Skeleton.line(width: 96, height: 18, radius: 6),
                        for (final amenity in venue.amenities.take(
                          free == null ? 2 : 1,
                        ))
                          _Tag(label: amenity),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Capped rather than flexible: a flexible column would split
              // the row evenly with the name and clip it at the default text
              // size, which is not where the pressure is.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.scaled(98, max: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // The unit rides with the number. Without it «₽1 600»
                    // reads as the price of a visit, and the search screen
                    // two taps away says «₽1 600/час» for the same club.
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: AppFormatters.money(venue.pricePerHour),
                            style: AppTheme.numeric(
                              context.text.titleMedium,
                            ).copyWith(fontWeight: FontWeight.w900),
                          ),
                          TextSpan(
                            text: context.l10n.perHourSuffix,
                            style: context.text.bodySmall?.copyWith(
                              color: colors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.star, size: 13, color: colors.ink),
                        const SizedBox(width: 3),
                        Flexible(
                          // Written short, read long: a reader hears
                          // "4.8 · 128 отзывов", the row shows what fits.
                          child: Semantics(
                            label: venue.reviewCount == null
                                ? null
                                : context.l10n.ratingWithReviews(
                                    venue.rating.toStringAsFixed(1),
                                    venue.reviewCount!,
                                  ),
                            child: Text(
                              venue.reviewCount == null
                                  ? venue.rating.toStringAsFixed(1)
                                  : '${venue.rating.toStringAsFixed(1)} · '
                                        '${venue.reviewCount}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: AppTheme.numeric(
                                context.text.labelSmall,
                              ).copyWith(color: colors.muted),
                            ),
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
      ),
    );
  }
}

enum _TagTone { plain, live }

/// What a club has, in its own word. Small, quiet, and only as many as fit —
/// except the one that answers the calendar, which is allowed to speak up.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.tone = _TagTone.plain});

  final String label;
  final _TagTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final live = tone == _TagTone.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: live ? colors.accentSoft : colors.bgAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          fontSize: 10.5,
          color: live ? colors.accent : colors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.query, required this.onReset});

  /// What was typed, if anything. The message used to name a covering the
  /// reader had never filtered by — «В Москве пока нет клубов с этим
  /// покрытием» in answer to a misspelled club name.
  final String query;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: EmptyState(
        icon: AppIcons.searchX,
        title: context.l10n.nothingFound,
        description: query.isEmpty
            ? context.l10n.noVenuesForSportHint
            : context.l10n.noVenuesForQueryHint(query),
        actionLabel: context.l10n.reset,
        onAction: onReset,
      ),
    );
  }
}
