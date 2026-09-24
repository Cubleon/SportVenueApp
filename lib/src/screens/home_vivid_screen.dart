import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/sport_surface.dart';

/// A second answer to the same screen: the two references as one page rather
/// than one stacked on the other.
///
/// There is no band and no seam. The page is a single field — saturated blue
/// at the top of the scroll, fading into the pale page colour and staying
/// there — and every piece of content is the same white card with the same
/// corner radius, whether it is sitting on the blue or on the pale. What the
/// loud reference contributes is not a zone but a set of habits repeated the
/// whole way down: display-weight type, balls breaking out of their
/// containers, one blue card in every row, and one warm colour that marks what
/// is urgent.
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

  /// The day the whole page is about. Everything below the calendar answers
  /// for this date and nothing else.
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  /// How many hours each club still has free on [_date], by club id. Empty
  /// until the first load answers, and reloaded whenever the day changes.
  Map<String, int> _freeSlots = const {};
  int _slotsToken = 0;

  /// The palette for this one screen. Local on purpose: a mood, not tokens.
  static const _bg = Color(0xFFF1EFFA);
  static const _ink = Color(0xFF14121C);
  static const _muted = Color(0xFF7B7791);
  static const _blue = Color(0xFF2F5BFF);
  static const _blueSoft = Color(0xFFE6EBFF);
  static const _skyTop = Color(0xFF2E86FF);
  static const _skyLow = Color(0xFF6AACFF);

  /// The one warm colour on the page. It marks what is running out — free
  /// places — and where you are in the bar, and nothing else. A hot accent
  /// only works while it stays rare.
  static const _hot = Color(0xFFFF4D3D);
  static const _hotSoft = Color(0xFFFFE9E6);

  static const _cardShadow = [
    BoxShadow(color: Color(0x14201A4A), blurRadius: 18, offset: Offset(0, 8)),
  ];

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

  /// Asks the same endpoint the booking screens ask. On the demo controller
  /// every day answers the same, so the count sits still here; against a
  /// server it moves with the date like everything else on the page.
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
        final empty = venues.isEmpty;
        final topInset = MediaQuery.viewPaddingOf(context).top;

        // The blue is a wash over the page colour, not a block on top of it:
        // it ends in exactly the page colour, so there is no edge to see.
        final fieldHeight = topInset + context.scaled(408, max: 1.3);

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
                SingleChildScrollView(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: fieldHeight,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_skyTop, _skyLow, _bg],
                              stops: [0, 0.58, 1],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CalendarHead(
                            controller: widget.controller,
                            topInset: topInset,
                            date: _date,
                            onPick: _pickDate,
                            gamesToday: games.length,
                            venuesToday: venues.length,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: _SearchField(
                              controller: _search,
                              onChanged: (value) => setState(
                                () => _query = value.trim().toLowerCase(),
                              ),
                            ),
                          ),
                          _SectionTitle(context.l10n.vividSports),
                          _CategoryRow(
                            sports: widget.controller.sports,
                            selected: _sportId,
                            onSelect: (id) => setState(() => _sportId = id),
                          ),
                          if (venues.isNotEmpty) ...[
                            _SectionTitle(
                              context.l10n.vividFreeOn(
                                AppFormatters.dateShort(_date),
                              ),
                            ),
                            SizedBox(
                              height: context.scaled(248, max: 1.4),
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: venues.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) => _VenueCard(
                                  venue: venues[index],
                                  sportId: _sportOf(venues[index]),
                                  freeSlots: _freeSlots[venues[index].id],
                                  // One blue card in the row, the way the
                                  // top of the page is blue: the accent
                                  // travels down instead of staying up there.
                                  accent: index == 0,
                                ),
                              ),
                            ),
                          ],
                          if (venues.isNotEmpty) ...[
                            _SectionTitle(context.l10n.openGames),
                            if (games.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                                child: _NoGamesCard(),
                              ),
                            for (final game in games)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  10,
                                ),
                                child: _GameCard(game: game),
                              ),
                          ],
                          if (empty) _NothingFound(onReset: _reset),
                          SizedBox(height: context.scaled(110, max: 1.3)),
                        ],
                      ),
                    ],
                  ),
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

/// The top of the page: the calendar the rest of the page answers to.
///
/// It keeps the loud reference's hierarchy without a headline stat — the
/// selected day grows into the big element instead, and the line under the
/// strip says what that day holds.
class _CalendarHead extends StatelessWidget {
  const _CalendarHead({
    required this.controller,
    required this.topInset,
    required this.date,
    required this.onPick,
    required this.gamesToday,
    required this.venuesToday,
  });

  final AppController controller;
  final double topInset;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  final int gamesToday;
  final int venuesToday;

  static const _days = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = DateUtils.dateOnly(DateTime.now());

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderPill(controller: controller),
              SizedBox(height: context.scaled(22, max: 1.4)),
              Row(
                children: [
                  Text(
                    l10n.vividWhen,
                    style: context.text.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppFormatters.monthGenitive(date),
                    style: context.text.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
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
                    final day = today.add(Duration(days: index));
                    return _DateCard(
                      date: day,
                      selected: DateUtils.isSameDay(day, date),
                      isToday: index == 0,
                      onTap: () => onPick(day),
                    );
                  },
                ),
              ),
              SizedBox(height: context.scaled(14, max: 1.3)),
              Text(
                '${l10n.vividGamesCount(gamesToday)} · '
                '${l10n.clubsNearby(venuesToday)}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // The balls flank the calendar rather than sitting under it: a strip
        // of glass cards over a ball turns both to mud.
        Positioned(
          left: -50,
          top: topInset - 10,
          child: _Ball(
            kind: _BallKind.soccer,
            size: context.scaled(86, max: 1.15),
          ),
        ),
        Positioned(
          right: -40,
          bottom: -26,
          child: _Ball(
            kind: _BallKind.basket,
            size: context.scaled(84, max: 1.15),
            tilt: 0.2,
          ),
        ),
      ],
    );
  }
}

/// One day. The chosen one grows and turns solid — the biggest, brightest
/// thing on the page is the thing everything else answers to.
class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 1 : 0.38),
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x33123A7A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppFormatters.weekdayShort(date),
                style: context.text.labelSmall?.copyWith(
                  color: selected
                      ? _HomeVividScreenState._muted
                      : Colors.white.withValues(alpha: 0.82),
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
                          color: selected
                              ? _HomeVividScreenState._blue
                              : Colors.white,
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
                    color: selected
                        ? _HomeVividScreenState._blue
                        : Colors.white.withValues(alpha: 0.9),
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

/// A day with clubs but no games still owes the reader a sentence.
class _NoGamesCard extends StatelessWidget {
  const _NoGamesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _HomeVividScreenState._cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _HomeVividScreenState._blueSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 19,
              color: _HomeVividScreenState._blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.noOpenGames,
              style: context.text.bodyMedium?.copyWith(
                color: _HomeVividScreenState._muted,
              ),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Half a ball behind the last tile: the same break-out the top of
          // the page does, repeated where the page has gone pale.
          Positioned(
            right: 8,
            top: -22,
            child: _Ball(
              kind: _BallKind.tennis,
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
  const _VenueCard({
    required this.venue,
    required this.sportId,
    this.accent = false,
    this.freeSlots,
  });

  final Venue venue;
  final String sportId;

  /// Free hours on the day the calendar is showing, or null while the answer
  /// is still on its way.
  final int? freeSlots;

  /// Blue instead of white. One card per row wears the page's own colour, so
  /// the accent is something the whole page does rather than a band at the
  /// top of it.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ink = accent ? Colors.white : _HomeVividScreenState._ink;
    final sub = accent
        ? Colors.white.withValues(alpha: 0.78)
        : _HomeVividScreenState._muted;

    return Container(
      width: context.scaled(176, max: 1.25),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent ? _HomeVividScreenState._blue : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: accent
            ? const [
                BoxShadow(
                  color: Color(0x452F5BFF),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ]
            : _HomeVividScreenState._cardShadow,
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
              if (freeSlots case final int free)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _HomeVividScreenState._blue,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      context.l10n.vividSlots(free),
                      style: context.text.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                        color: accent
                            ? Colors.white
                            : _HomeVividScreenState._blue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: accent
                            ? _HomeVividScreenState._blue
                            : Colors.white,
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
                    color: _HomeVividScreenState._hotSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    context.l10n.freePlaces(game.freePlaces),
                    style: context.text.labelSmall?.copyWith(
                      color: _HomeVividScreenState._hot,
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
                    0 => _HomeVividScreenState._hotSoft,
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
