import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/sport_surface.dart';

/// A second answer to the same screen, in the register the delivery apps use.
///
/// Same data as the quiet home — the city, the sports, the clubs, their
/// prices, the open games — laid out the way a grocery app lays out food: a
/// pale page, white cards floating on it with generous corners, one banner
/// doing the selling, a row of round category tiles, and a single saturated
/// accent that every tappable thing borrows. The accent here is blue.
///
/// Nothing is invented: no discount that does not exist, no badge for a
/// promotion nobody ran. The loudness is in the layout and the colour, not in
/// claims about the product.
///
/// What responds to a tap: the search field, the category tiles, and the
/// filter they drive. The cards and the bottom bar are drawn, not wired — this
/// is a screen to look at next to the shipping home, not a second home
/// competing with it.
class HomeVividScreen extends StatefulWidget {
  const HomeVividScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeVividScreen> createState() => _HomeVividScreenState();
}

class _HomeVividScreenState extends State<HomeVividScreen> {
  final TextEditingController _search = TextEditingController();

  String _sportId = 'all';
  String _query = '';

  /// The palette for this one screen. Local on purpose: a mood, not tokens.
  static const _bg = Color(0xFFF1EFFA);
  static const _ink = Color(0xFF14121C);
  static const _muted = Color(0xFF7B7791);
  static const _blue = Color(0xFF2F5BFF);
  static const _blueSoft = Color(0xFFE6EBFF);

  static const _cardShadow = [
    BoxShadow(color: Color(0x14201A4A), blurRadius: 18, offset: Offset(0, 8)),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
            (_sportId == 'all' || game.sportId == _sportId) &&
            (_matches(game.venue.name) || _matches(game.venue.address)),
      )
      .toList();

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
        final venues = _venues;
        final games = _games;
        final empty = venues.isEmpty && games.isEmpty;

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _AddressBar(controller: widget.controller),
                    ),
                    SliverToBoxAdapter(
                      child: _SearchRow(
                        controller: _search,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                    ),
                    if (games.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _Banner.forGame(context, games.first),
                      )
                    else if (venues.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _Banner.forVenue(
                          context,
                          venues.first,
                          _sportOf(venues.first),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: _SectionTitle(context.l10n.vividSports),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryRow(
                        sports: widget.controller.sports,
                        selected: _sportId,
                        onSelect: (id) => setState(() => _sportId = id),
                      ),
                    ),
                    if (venues.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionTitle(context.l10n.vividFreeToday),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: context.scaled(248, max: 1.4),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: venues.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => _VenueCard(
                              venue: venues[index],
                              sportId: _sportOf(venues[index]),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (games.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionTitle(context.l10n.openGames),
                      ),
                      SliverList.separated(
                        itemCount: games.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _GameCard(game: games[index]),
                        ),
                      ),
                    ],
                    if (empty)
                      SliverToBoxAdapter(child: _NothingFound(onReset: _reset)),
                    SliverToBoxAdapter(
                      child: SizedBox(height: context.scaled(110, max: 1.3)),
                    ),
                  ],
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomBar(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _sportOf(Venue venue) {
    if (_sportId != 'all' && venue.sportIds.contains(_sportId)) {
      return _sportId;
    }
    return venue.sportIds.first;
  }
}

/// Where you are and who you are — the line the grocery apps open with,
/// because it is the one thing that changes what everything below means.
class _AddressBar extends StatelessWidget {
  const _AddressBar({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.vividWhereToPlay,
                  style: context.text.labelSmall?.copyWith(
                    color: _HomeVividScreenState._muted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: _HomeVividScreenState._ink,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.l10n.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium?.copyWith(
                          color: _HomeVividScreenState._ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: context.scaled(48, max: 1.3),
            height: context.scaled(48, max: 1.3),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: _HomeVividScreenState._cardShadow,
            ),
            child: Text(
              controller.greetingName.characters.first.toUpperCase(),
              style: context.text.titleMedium?.copyWith(
                color: _HomeVividScreenState._blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: context.scaled(54, max: 1.4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                boxShadow: _HomeVividScreenState._cardShadow,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _HomeVividScreenState._muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      cursorColor: _HomeVividScreenState._blue,
                      style: context.text.bodyMedium?.copyWith(
                        color: _HomeVividScreenState._ink,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: context.l10n.searchFieldHint,
                        hintStyle: context.text.bodyMedium?.copyWith(
                          color: _HomeVividScreenState._muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: context.scaled(54, max: 1.4),
            height: context.scaled(54, max: 1.4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: _HomeVividScreenState._cardShadow,
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 20,
              color: _HomeVividScreenState._ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one card that sells. A playing surface behind it, a blue wash over it,
/// and three lines of the same facts that sit in a list further down.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.sportId,
    required this.chip,
    required this.title,
    required this.line,
    required this.pill,
  });

  factory _Banner.forGame(BuildContext context, Game game) => _Banner(
    sportId: game.sportId,
    chip: context.l10n.vividNextGame,
    title: game.venue.name.capitalized,
    line: context.l10n.gameWhen(
      AppFormatters.dateShort(game.date),
      game.timeRange,
    ),
    pill: game.isFull
        ? AppFormatters.money(game.pricePerPerson)
        : context.l10n.freePlaces(game.freePlaces),
  );

  factory _Banner.forVenue(BuildContext context, Venue venue, String sportId) =>
      _Banner(
        sportId: sportId,
        chip: context.l10n.vividNearby,
        title: venue.name.capitalized,
        line: context.l10n.venueAddressDistance(
          venue.address,
          venue.distanceKm.toStringAsFixed(1),
        ),
        pill: context.l10n.vividFrom(AppFormatters.money(venue.pricePerHour)),
      );

  final String sportId;
  final String chip;
  final String title;
  final String line;
  final String pill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: context.scaled(186, max: 1.35),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332F5BFF),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SportSurface(sportId: sportId),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xCC2F5BFF), Color(0xF0141C4D)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      chip,
                      style: context.text.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          pill,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelLarge?.copyWith(
                            color: _HomeVividScreenState._blue,
                            fontWeight: FontWeight.w800,
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
      child: Text(
        label,
        style: context.text.titleLarge?.copyWith(
          color: _HomeVividScreenState._ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

/// The category tiles. They are the filter — one control, not a decorative
/// row above a second set of chips doing the same job.
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
    final id = sportId;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
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
                  color: selected
                      ? _HomeVividScreenState._blueSoft
                      : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected
                        ? _HomeVividScreenState._blue
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: _HomeVividScreenState._cardShadow,
                ),
                child: id == null
                    ? const Icon(
                        Icons.apps_rounded,
                        color: _HomeVividScreenState._blue,
                      )
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
                  color: selected
                      ? _HomeVividScreenState._blue
                      : _HomeVividScreenState._muted,
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

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.sportId});

  final Venue venue;
  final String sportId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.scaled(176, max: 1.25),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _HomeVividScreenState._cardShadow,
      ),
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
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: _HomeVividScreenState._blue,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        venue.rating.toStringAsFixed(1),
                        style: context.text.labelSmall?.copyWith(
                          color: _HomeVividScreenState._ink,
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
                      color: _HomeVividScreenState._ink,
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
                  style: context.text.labelSmall?.copyWith(
                    color: _HomeVividScreenState._muted,
                  ),
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
                          color: _HomeVividScreenState._ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: _HomeVividScreenState._blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: Colors.white,
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

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _HomeVividScreenState._cardShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: context.scaled(58, max: 1.2),
              height: context.scaled(58, max: 1.2),
              child: SportSurface(sportId: game.sportId),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.venue.name.capitalized,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: _HomeVividScreenState._ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.gameWhen(
                    AppFormatters.dateShort(game.date),
                    game.timeRange,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: _HomeVividScreenState._muted,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _HomeVividScreenState._blueSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    context.l10n.freePlaces(game.freePlaces),
                    style: context.text.labelSmall?.copyWith(
                      color: _HomeVividScreenState._blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppFormatters.money(game.pricePerPerson),
            style: context.text.titleSmall?.copyWith(
              color: _HomeVividScreenState._ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          Text(
            context.l10n.nothingFound,
            style: context.text.titleMedium?.copyWith(
              color: _HomeVividScreenState._ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: _HomeVividScreenState._blue,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                context.l10n.reset,
                style: context.text.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drawn, not wired: the shipping app's tab bar is the one that navigates.
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.add_rounded,
      Icons.sports_soccer_rounded,
      Icons.person_rounded,
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Container(
        height: context.scaled(68, max: 1.25),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2620194F),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < icons.length; i++)
              Container(
                width: context.scaled(46, max: 1.2),
                height: context.scaled(46, max: 1.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (i) {
                    0 => _HomeVividScreenState._ink,
                    2 => _HomeVividScreenState._blue,
                    _ => Colors.transparent,
                  },
                ),
                child: Icon(
                  icons[i],
                  size: 21,
                  color: i == 0 || i == 2
                      ? Colors.white
                      : _HomeVividScreenState._muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
