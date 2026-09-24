import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/sport_surface.dart';

/// A second answer to the same screen: the loud half and the calm half of the
/// references, in one page.
///
/// The top is the bright one — saturated blue running edge to edge under the
/// status bar, one fact blown up to a third of the screen, and balls that
/// break out of the block onto the page below. The rest is the grocery-app
/// one — a pale page, white cards with generous corners, round category tiles,
/// a floating bar. The search field straddles the seam between them, which is
/// what keeps the two halves reading as one screen rather than two pasted
/// together.
///
/// Nothing is invented: no discount that does not exist, no badge for a
/// promotion nobody ran. The big number is the next real game's kick-off, the
/// pills beside it its real price and its real free places.
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
  static const _skyTop = Color(0xFF2E86FF);
  static const _skyLow = Color(0xFF5BA6FF);

  /// The one warm colour on the page. It marks where you are in the bar and
  /// nothing else — a single hot accent is what the references do, and it only
  /// works while it stays rare.
  static const _hot = Color(0xFFFF4D3D);

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

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: _bg,
            body: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Hero(
                        controller: widget.controller,
                        game: games.isNotEmpty ? games.first : null,
                        venue: venues.isNotEmpty ? venues.first : null,
                        search: _search,
                        onQuery: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
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

/// The loud half: blue to the very top of the glass, one fact at display size,
/// and balls that leave the block.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.controller,
    required this.game,
    required this.venue,
    required this.search,
    required this.onQuery,
  });

  final AppController controller;
  final Game? game;
  final Venue? venue;
  final TextEditingController search;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = game;
    final club = current?.venue ?? venue;

    final (String, String, String)? headline = switch (current) {
      final Game g => (
        l10n.vividNextGame,
        '${g.startHour.toString().padLeft(2, '0')}:00',
        '${AppFormatters.dateShort(g.date)} · ${g.venue.name.capitalized}',
      ),
      _ => switch (venue) {
        final Venue v => (
          l10n.vividNearby,
          AppFormatters.money(v.pricePerHour),
          '${v.name.capitalized} · ${v.distanceKm.toStringAsFixed(1)} км',
        ),
        // Nothing matched the search: the block keeps its colour and its
        // header, and says nothing rather than saying it with a dash.
        _ => null,
      },
    };

    // Half the search field hangs below the blue, onto the page.
    const overhang = 30.0;
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Padding(
      padding: const EdgeInsets.only(bottom: overhang),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, overhang + 46),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _HomeVividScreenState._skyTop,
                  _HomeVividScreenState._skyLow,
                ],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderPill(controller: controller),
                if (headline case (final label, final display, final line)) ...[
                  SizedBox(height: context.scaled(26, max: 1.4)),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.text.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    display,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: context.text.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                      height: 1.12,
                      shadows: const [
                        Shadow(
                          color: Color(0x452A5FA8),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.scaled(16, max: 1.4)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (current != null && !current.isFull)
                        _HeroPill(
                          text: l10n.freePlaces(current.freePlaces),
                          solid: true,
                        ),
                      if (current != null && !current.isFull)
                        const SizedBox(width: 8),
                      if (current != null)
                        _HeroPill(
                          text: AppFormatters.money(current.pricePerPerson),
                        )
                      else if (club != null)
                        _HeroPill(
                          text: l10n.rating(club.rating.toStringAsFixed(1)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // The balls sit behind the type and spill past the block — the trick
          // the bright references use to get depth out of a flat background.
          // They go with it: over a block shrunk to its header they would just
          // be litter on the page.
          if (headline != null) ...[
            Positioned(
              left: -34,
              top: topInset + 88,
              child: _Ball(
                kind: _BallKind.soccer,
                size: context.scaled(104, max: 1.15),
              ),
            ),
            Positioned(
              right: -30,
              top: topInset + 100,
              child: _Ball(
                kind: _BallKind.basket,
                size: context.scaled(92, max: 1.15),
                tilt: 0.2,
              ),
            ),
            Positioned(
              right: -16,
              bottom: 56,
              child: _Ball(
                kind: _BallKind.tennis,
                size: context.scaled(56, max: 1.1),
                tilt: -0.3,
              ),
            ),
          ],
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: _SearchField(controller: search, onChanged: onQuery),
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A123A7A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: context.scaled(42, max: 1.25),
            height: context.scaled(42, max: 1.25),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _HomeVividScreenState._blue,
                  _HomeVividScreenState._skyLow,
                ],
              ),
            ),
            child: Text(
              controller.greetingName.characters.first.toUpperCase(),
              style: context.text.titleMedium?.copyWith(
                color: Colors.white,
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
                    const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: _HomeVividScreenState._muted,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        context.l10n.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: _HomeVividScreenState._muted,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  controller.greetingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: _HomeVividScreenState._ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _HomeVividScreenState._blueSoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              context.l10n.clubsNearby(controller.venues.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.text, this.solid = false});

  final String text;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: solid ? Colors.white : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
        border: solid
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelLarge?.copyWith(
          color: solid ? _HomeVividScreenState._blue : Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: context.scaled(60, max: 1.4),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A123A7A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 21,
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
          Container(
            width: context.scaled(38, max: 1.2),
            height: context.scaled(38, max: 1.2),
            decoration: const BoxDecoration(
              color: _HomeVividScreenState._blueSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 18,
              color: _HomeVividScreenState._blue,
            ),
          ),
        ],
      ),
    );
  }
}

enum _BallKind { soccer, basket, tennis }

/// Drawn, not photographed. The references float 3-D renders; a ball painted
/// from a couple of gradients and four arcs gets most of that lift without
/// shipping a megabyte of PNG per sport.
class _Ball extends StatelessWidget {
  const _Ball({required this.kind, required this.size, this.tilt = 0});

  final _BallKind kind;
  final double size;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x4D0B2A66),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: CustomPaint(painter: _BallPainter(kind)),
      ),
    );
  }
}

class _BallPainter extends CustomPainter {
  const _BallPainter(this.kind);

  final _BallKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);

    final base = switch (kind) {
      _BallKind.soccer => Colors.white,
      _BallKind.basket => const Color(0xFFF2802A),
      _BallKind.tennis => const Color(0xFFD9F24B),
    };
    canvas.drawCircle(c, r, Paint()..color = base);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    switch (kind) {
      case _BallKind.soccer:
        final dark = Paint()..color = const Color(0xFF15131C);
        for (final (dx, dy, k) in const [
          (0.0, -0.58, 0.22),
          (-0.56, 0.2, 0.19),
          (0.56, 0.22, 0.19),
          (0.0, 0.78, 0.18),
        ]) {
          canvas.drawCircle(c + Offset(dx * r, dy * r), k * r, dark);
        }
      case _BallKind.basket:
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.075
          ..color = const Color(0xCC170A00);
        canvas.drawLine(Offset(0, r), Offset(size.width, r), line);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 0.9, height: size.height * 1.5),
          line,
        );
        canvas.drawOval(
          Rect.fromCenter(center: c, width: size.width * 1.5, height: r * 0.9),
          line,
        );
      case _BallKind.tennis:
        final seam = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..color = Colors.white;
        canvas.drawArc(
          Rect.fromCenter(
            center: c + Offset(-r * 0.92, 0),
            width: r * 1.5,
            height: size.height * 1.05,
          ),
          -math.pi / 2.4,
          math.pi / 1.2,
          false,
          seam,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: c + Offset(r * 0.92, 0),
            width: r * 1.5,
            height: size.height * 1.05,
          ),
          math.pi / 1.7,
          math.pi / 1.2,
          false,
          seam,
        );
    }
    canvas.restore();

    // Light from the upper left, shade at the lower right: the two gradients
    // that turn a disc into a sphere.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.45, 0.6),
          radius: 0.95,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(
              alpha: kind == _BallKind.soccer ? 0.2 : 0.32,
            ),
          ],
          stops: const [0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BallPainter oldDelegate) => oldDelegate.kind != kind;
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
                    0 => const Color(0xFFFFE9E6),
                    2 => _HomeVividScreenState._blue,
                    _ => Colors.transparent,
                  },
                ),
                child: Icon(
                  icons[i],
                  size: 21,
                  color: switch (i) {
                    0 => _HomeVividScreenState._hot,
                    2 => Colors.white,
                    _ => _HomeVividScreenState._muted,
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
