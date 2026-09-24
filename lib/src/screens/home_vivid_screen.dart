import 'dart:ui';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/sport_surface.dart';

/// A second answer to the same screen, in the loud register.
///
/// Same data as the quiet home — the city, the sports, the recommended
/// clubs, their prices — arranged the way a delivery app arranges a pizza:
/// the subject cut out and floating over a coloured sky, the name in
/// display type across it, and the price in a pill you could hit with your
/// eyes shut.
///
/// It keeps the app's radii and typeface so it still reads as the same
/// product, and carries its own colours rather than borrowing the palette:
/// these gradients are a mood for one screen, not tokens for a system. Kept
/// apart from the shipping home on purpose — this is something to look at
/// next to it, not a replacement decided by whoever edits last.
class HomeVividScreen extends StatefulWidget {
  const HomeVividScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeVividScreen> createState() => _HomeVividScreenState();
}

class _HomeVividScreenState extends State<HomeVividScreen> {
  String _sportId = 'all';

  /// The sky behind everything. Two of them, so the page changes mood as it
  /// scrolls rather than sitting in one wash.
  static const _skyTop = Color(0xFF6B5CFF);
  static const _skyMid = Color(0xFFFF7BAC);
  static const _skyLow = Color(0xFFFFC46B);
  static const _ink = Color(0xFF16131F);

  List<Venue> get _venues {
    final all = widget.controller.venues;
    if (_sportId == 'all') {
      return all;
    }
    return all.where((venue) => venue.sportIds.contains(_sportId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final venues = _venues;
        return Scaffold(
          backgroundColor: _skyTop,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_skyTop, _skyMid, _skyLow],
                stops: [0, 0.45, 1],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _TopBar(controller: widget.controller),
                  ),
                  const SliverToBoxAdapter(child: _StoryRow()),
                  SliverToBoxAdapter(
                    child: _SportPills(
                      sports: widget.controller.sports,
                      selected: _sportId,
                      onSelect: (id) => setState(() => _sportId = id),
                    ),
                  ),
                  if (venues.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _HeroCard(
                        venue: venues.first,
                        sportId: _sportOf(venues.first),
                      ),
                    ),
                  if (venues.length > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                        child: Text(
                          context.l10n.vividPickedForYou,
                          style: context.text.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                  SliverList.separated(
                    itemCount: venues.length > 1 ? venues.length - 1 : 0,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final venue = venues[index + 1];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _VenueTile(
                          venue: venue,
                          sportId: _sportOf(venue),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
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

/// Where you are and who you are, floating on the sky rather than sitting
/// on a bar of its own.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _Glass(
              padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
              radius: 99,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.l10n.vividFreeNow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Glass(
            radius: 99,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: context.scaled(44),
              height: context.scaled(44),
              child: Center(
                child: Text(
                  controller.greetingName.characters.first.toUpperCase(),
                  style: context.text.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

/// The row of small coloured cards the delivery apps put under the address:
/// a shortcut each, bright enough to be tapped without reading.
class _StoryRow extends StatelessWidget {
  const _StoryRow();

  @override
  Widget build(BuildContext context) {
    final stories = <({String label, List<Color> colors, IconData icon})>[
      (
        label: context.l10n.vividNearby,
        colors: const [Color(0xFF2BD9A8), Color(0xFF0FA3A3)],
        icon: Icons.near_me_rounded,
      ),
      (
        label: context.l10n.vividTonight,
        colors: const [Color(0xFFFF8A3D), Color(0xFFFF4D8D)],
        icon: Icons.nightlight_round,
      ),
      (
        label: context.l10n.vividNewVenues,
        colors: const [Color(0xFF7C5CFF), Color(0xFF3AA0FF)],
        icon: Icons.auto_awesome_rounded,
      ),
    ];

    return SizedBox(
      height: context.scaled(104, max: 1.6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final story = stories[index];
          return Semantics(
            button: true,
            child: Container(
              width: context.scaled(104, max: 1.4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: story.colors,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(story.icon, color: Colors.white, size: 20),
                  Text(
                    story.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SportPills extends StatelessWidget {
  const _SportPills({
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
      height: context.scaled(46),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        children: [
          _Pill(
            label: context.l10n.allFilter,
            selected: selected == 'all',
            onTap: () => onSelect('all'),
          ),
          for (final sport in sports) ...[
            const SizedBox(width: 8),
            _Pill(
              label: sport.name.capitalized,
              selected: selected == sport.id,
              onTap: () => onSelect(sport.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 1 : 0.35),
            ),
          ),
          child: Text(
            label,
            style: context.text.labelLarge?.copyWith(
              color: selected ? _HomeVividScreenState._ink : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one that does the work: the pitch cut out and floating, the name
/// across it, the price in a pill.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.venue, required this.sportId});

  final Venue venue;
  final String sportId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Semantics(
        button: true,
        child: Container(
          height: context.scaled(430, max: 1.35),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF9BD7FF), Color(0xFFFFB3D2)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            // The pitch is allowed out of the card: an object that breaks
            // its own frame reads as lifted off the page, which is the trick
            // the references are doing with food.
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      // Clouds, as two soft blooms rather than a picture
                      // nobody shipped.
                      Positioned(
                        left: -40,
                        top: 40,
                        child: _Bloom(size: context.scaled(200, max: 1.2)),
                      ),
                      Positioned(
                        right: -60,
                        top: 150,
                        child: _Bloom(size: context.scaled(240, max: 1.2)),
                      ),
                    ],
                  ),
                ),
              ),
              // The pitch, tilted and lifted off the card — the trick the
              // pizza is doing.
              Positioned(
                top: context.scaled(34, max: 1.3),
                left: -26,
                right: -26,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.14,
                    child: Container(
                      width: context.scaled(320, max: 1.2),
                      height: context.scaled(210, max: 1.2),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 26,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: SportSurface(sportId: sportId),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // The card stopped clipping so the pitch could escape it,
                // so the scrim has to keep its own corners.
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            venue.name.capitalized,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            venue.description.capitalized,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _Glass(
                                radius: 99,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      venue.rating.toStringAsFixed(1),
                                      style: context.text.labelLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5A1F),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  context.l10n.vividFrom(
                                    AppFormatters.money(venue.pricePerHour),
                                  ),
                                  style: context.text.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ones under the hero: same idea, laid on its side.
class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.venue, required this.sportId});

  final Venue venue;
  final String sportId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: _Glass(
        radius: 26,
        dark: true,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: context.scaled(78),
                height: context.scaled(78),
                child: SportSurface(sportId: sportId),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name.capitalized,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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
                    style: context.text.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        venue.rating.toStringAsFixed(1),
                        style: context.text.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.l10n.pricePerHour(
                          AppFormatters.money(venue.pricePerHour),
                        ),
                        style: context.text.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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

/// A frosted panel. The references lean on these hard: content sits on the
/// sky rather than on a page.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    required this.padding,
    this.radius = 20,
    this.dark = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// Frosted dark rather than frosted light. A white panel holds white text
  /// over the violet at the top of the sky and loses it entirely over the
  /// peach at the bottom; a dark one works the whole way down.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: dark
                ? Colors.black.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.18 : 0.32),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
