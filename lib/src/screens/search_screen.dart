import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/sky_header.dart';
import '../widgets/sport_ball.dart';
import 'booking_screens.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _mapStyle = 'https://tiles.openfreemap.org/styles/dark';
  static const _moscowCenter = maplibre.Geographic(lon: 37.6173, lat: 55.7558);
  static const _moscowZoom = 10.6;

  String _sportId = 'all';
  Venue? _selectedVenue;
  maplibre.MapController? _mapController;
  final _searchController = TextEditingController();
  final _sheetController = DraggableScrollableController();

  /// Three rests: out of the way, showing the first couple of results, and
  /// reading the list. Tapping a pin raises it to the middle one.
  static const _sheetPeek = 0.18;
  static const _sheetOpen = 0.42;
  static const _sheetFull = 0.92;

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  List<Venue> get _venues {
    final query = _searchController.text.trim().toLowerCase();
    return widget.controller.venues.where((venue) {
      if (_sportId != 'all' && !venue.sportIds.contains(_sportId)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return venue.name.toLowerCase().contains(query) ||
          venue.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final venues = _venues;
    final query = _searchController.text.trim();
    return Stack(
      children: [
        Column(
          children: [
            SkyHeader(
              title: context.l10n.search,
              subtitle: context.l10n.searchSubtitle,
              ball: SportBallKind.tennis,
              trailing: SkyIconButton(
                icon: Icons.my_location_rounded,
                label: context.l10n.centreOnMoscow,
                onTap: _focusMoscow,
              ),
              child: _SearchField(
                controller: _searchController,
                onChanged: (_) => setState(() => _selectedVenue = null),
              ),
            ),
            SizedBox(
              height: context.scaled(46),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  SelectableChip(
                    label: context.l10n.allFilter,
                    selected: _sportId == 'all',
                    onTap: () => setState(() => _sportId = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ...widget.controller.sports.map(
                    (sport) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectableChip(
                        label: sport.name.capitalized,
                        icon: sport.icon,
                        selected: _sportId == sport.id,
                        onTap: () => setState(() => _sportId = sport.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  context.bottomBarInset,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      maplibre.MapLibreMap(
                        options: const maplibre.MapOptions(
                          initStyle: _mapStyle,
                          initCenter: _moscowCenter,
                          initZoom: _moscowZoom,
                          minZoom: 8,
                          maxZoom: 18,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        children: [
                          maplibre.WidgetLayer(
                            allowInteraction: true,
                            markers: venues
                                .map(
                                  (venue) => maplibre.Marker(
                                    point: venue.mapPoint,
                                    size: const Size(58, 64),
                                    alignment: Alignment.bottomCenter,
                                    child: _MapMarker(
                                      venue: venue,
                                      sport: _sportForVenue(venue),
                                      isSelected:
                                          _selectedVenue?.id == venue.id,
                                      onTap: () => _selectVenue(venue),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const maplibre.MapCompass(
                            alignment: Alignment.topRight,
                            padding: EdgeInsets.all(12),
                            radius: 19,
                          ),
                          const maplibre.SourceAttribution(
                            alignment: Alignment.bottomLeft,
                            padding: EdgeInsets.all(10),
                            showMapLibre: false,
                          ),
                        ],
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: context.colors.border),
                            ),
                          ),
                        ),
                      ),
                      // The results, as a list, over the map they are
                      // plotted on. A map alone answers "where is it" and
                      // nothing else: a name typed into the field could
                      // match a single club three screens away, and the
                      // only sign of it was a pin nobody was looking at.
                      _ResultsSheet(
                        controller: widget.controller,
                        sheetController: _sheetController,
                        venues: venues,
                        sportOf: _sportForVenue,
                        selected: _selectedVenue,
                        query: query,
                        onPick: _openVenue,
                        onReset: () => setState(() {
                          _sportId = 'all';
                          _searchController.clear();
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Opens a club from the list. The map keeps up, so coming back leaves
  /// the pin where the eye last had it.
  void _openVenue(Venue venue) {
    _selectVenue(venue);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BookingScreen(controller: widget.controller, venue: venue),
      ),
    );
  }

  void _selectVenue(Venue venue) {
    setState(() => _selectedVenue = venue);
    if (_sheetController.isAttached && _sheetController.size < _sheetOpen) {
      _sheetController.animateTo(
        _sheetOpen,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    _mapController?.animateCamera(
      center: venue.mapPoint,
      zoom: 12.8,
      nativeDuration: const Duration(milliseconds: 650),
      webMaxDuration: const Duration(milliseconds: 650),
      padding: const EdgeInsets.only(bottom: 160),
    );
  }

  /// The sport a club is shown as. Under a filter it is the filtered one —
  /// a club listed under "хоккей" drawing a football pitch reads as the
  /// wrong club.
  Sport? _sportForVenue(Venue venue) {
    for (final sport in widget.controller.sports) {
      if (sport.id == _sportId && venue.sportIds.contains(sport.id)) {
        return sport;
      }
    }
    for (final sport in widget.controller.sports) {
      if (venue.sportIds.contains(sport.id)) {
        return sport;
      }
    }
    return null;
  }

  Future<void> _focusMoscow() async {
    setState(() => _selectedVenue = null);
    final controller = _mapController;
    if (controller == null) {
      showAppSnack(context, context.l10n.mapLoading);
      return;
    }
    await controller.animateCamera(
      center: _moscowCenter,
      zoom: _moscowZoom,
      pitch: 0,
      bearing: 0,
      nativeDuration: const Duration(milliseconds: 650),
      webMaxDuration: const Duration(milliseconds: 650),
    );
  }
}

/// The search field.
///
/// It used to be a Text in a card: it looked like an input and did nothing.
/// Now it filters the venues, and the trailing button clears the query
/// instead of standing there inert.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // It sits on the header's colour now, so it brings no outer padding of
    // its own — the header owns the margins.
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: context.colors.dim),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('venue-search-field'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: context.text.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: context.l10n.searchFieldHint,
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            Semantics(
              button: true,
              label: context.l10n.clearSearch,
              child: InkWell(
                key: const ValueKey('venue-search-clear'),
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: context.colors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.venue,
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  final Venue venue;
  final Sport? sport;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? sport?.color ?? context.colors.accent
        : context.colors.accent;
    return Semantics(
      button: true,
      label: venue.name.capitalized,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: isSelected ? 1.08 : 1,
          child: SizedBox(
            width: 58,
            height: 64,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.ink.withValues(alpha: 0.32),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.34),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      sport?.icon ?? '•',
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border(
                        right: BorderSide(
                          color: context.colors.ink.withValues(alpha: 0.22),
                          width: 2,
                        ),
                        bottom: BorderSide(
                          color: context.colors.ink.withValues(alpha: 0.22),
                          width: 2,
                        ),
                      ),
                    ),
                    transform: Matrix4.rotationZ(0.7853981634),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension _VenueMapPoint on Venue {
  maplibre.Geographic get mapPoint {
    return maplibre.Geographic(lon: longitude, lat: latitude);
  }
}

/// The results, as a sheet that can be pulled up over the map.
///
/// It rests low enough to leave the map readable, and every club is one
/// scroll away rather than one lucky tap on a pin.
class _ResultsSheet extends StatelessWidget {
  const _ResultsSheet({
    required this.controller,
    required this.sheetController,
    required this.venues,
    required this.sportOf,
    required this.selected,
    required this.query,
    required this.onPick,
    required this.onReset,
  });

  final AppController controller;
  final DraggableScrollableController sheetController;
  final List<Venue> venues;
  final Sport? Function(Venue) sportOf;
  final Venue? selected;
  final String query;
  final ValueChanged<Venue> onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: _SearchScreenState._sheetOpen,
      minChildSize: _SearchScreenState._sheetPeek,
      maxChildSize: _SearchScreenState._sheetFull,
      snap: true,
      snapSizes: const [
        _SearchScreenState._sheetPeek,
        _SearchScreenState._sheetOpen,
        _SearchScreenState._sheetFull,
      ],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: context.colors.ink.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  venues.isEmpty
                      ? context.l10n.nothingFound
                      : context.l10n.clubsNearby(venues.length),
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (venues.isEmpty)
                // An empty map is indistinguishable from a broken one, so
                // say which filter emptied it.
                EmptyState(
                  key: const ValueKey('search-empty'),
                  icon: query.isEmpty
                      ? Icons.location_off_rounded
                      : Icons.search_off_rounded,
                  title: query.isEmpty
                      ? context.l10n.noVenuesForSport
                      : context.l10n.nothingFound,
                  description: query.isEmpty
                      ? context.l10n.noVenuesForSportHint
                      : context.l10n.nothingFoundFor(query),
                  actionLabel: context.l10n.resetSearch,
                  onAction: onReset,
                )
              else
                for (final venue in venues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VenueRow(
                      key: ValueKey('search-result-${venue.id}'),
                      venue: venue,
                      sport: sportOf(venue),
                      selected: selected?.id == venue.id,
                      color: context.colors.bgAlt,
                      onTap: () => onPick(venue),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
