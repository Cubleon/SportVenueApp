import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_icons.dart';

import '../../l10n/l10n.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../router.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/sky_header.dart';
import '../widgets/map_clusters.dart';
import '../widgets/venue_filters.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// The map follows the theme: the dark style on a light screen was a black
  /// slab in the middle of a pale page.
  static String _mapStyleFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? 'https://tiles.openfreemap.org/styles/dark'
      : 'https://tiles.openfreemap.org/styles/positron';
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
  static const _sheetOpen = 0.55;
  static const _sheetFull = 0.92;

  VenueFilters _filters = VenueFilters.none;

  /// The map draws from tiles on the network and says nothing when they do
  /// not come. A style that has not loaded in this long is taken as a map
  /// that will not, and the screen says so instead of showing a grey box.
  static const _mapPatience = Duration(seconds: 15);
  Timer? _mapWatch;
  bool _mapFailed = false;

  /// Bumped to build a fresh map when the reader asks to try again.
  int _mapAttempt = 0;

  /// What the map shows, as of its last stop: the list under it names the
  /// free courts there, nearest to the middle first.
  maplibre.LngLatBounds? _view;
  maplibre.Geographic _viewCentre = _moscowCenter;

  /// Free courts listed under the clubs. More than this is a wall of
  /// identical rows; the map is the way to the rest.
  static const _nearbyLimit = 30;

  @override
  void initState() {
    super.initState();
    _watchMap();
    widget.controller.loadOpenPlaces().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onMapEvent(maplibre.MapEvent event) {
    if (event is maplibre.MapEventCameraIdle) _readView();
  }

  void _readView() {
    final map = _mapController;
    if (map == null || !mounted) return;
    try {
      final view = map.getVisibleRegion();
      final centre = map.getCamera().center;
      setState(() {
        _view = view;
        _viewCentre = centre;
      });
    } on Object {
      // The map is not ready to say what it shows; the list keeps the last.
    }
  }

  void _watchMap() {
    _mapWatch?.cancel();
    _mapWatch = Timer(_mapPatience, () {
      if (mounted) {
        setState(() => _mapFailed = true);
      }
    });
  }

  void _mapLoaded() {
    _mapWatch?.cancel();
    _readView();
    if (mounted && _mapFailed) {
      setState(() => _mapFailed = false);
    }
  }

  void _retryMap() {
    setState(() {
      _mapAttempt++;
      _mapFailed = false;
      _mapController = null;
    });
    _watchMap();
  }

  Future<void> _openFilters() async {
    final picked = await showVenueFilters(
      context,
      current: _filters,
      venues: widget.controller.venues,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _filters = picked;
      _selectedVenue = null;
    });
  }

  @override
  void dispose() {
    _mapWatch?.cancel();
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  bool _matches(Venue venue, String query) {
    if (_sportId != 'all' && !venue.sportIds.contains(_sportId)) {
      return false;
    }
    if (!_filters.allows(venue)) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    return venue.name.toLowerCase().contains(query) ||
        venue.address.toLowerCase().contains(query);
  }

  /// The filtered clubs and courts, worked out again only when something
  /// that filters them changes: the map groups them by the same lists, and
  /// new lists on every rebuild would regroup thousands of courts for
  /// nothing.
  Object? _listsKey;
  List<Venue> _clubs = const [];
  List<Venue> _places = const [];

  void _refreshLists() {
    final query = _searchController.text.trim().toLowerCase();
    final key = (
      _sportId,
      query,
      _filters,
      widget.controller.venues,
      widget.controller.openPlaces,
    );
    if (key == _listsKey) return;
    _listsKey = key;
    _clubs = widget.controller.venues
        .where((venue) => _matches(venue, query))
        .toList();
    _places = widget.controller.openPlaces
        .where((place) => _matches(place, query))
        .toList();
  }

  /// The free courts in view, nearest to the middle of the map first.
  (int, List<Venue>) get _nearbyPlaces {
    final view = _view;
    if (_places.isEmpty || view == null) return (0, const []);
    final inView = _places
        .where((place) => _inside(view, place.latitude, place.longitude))
        .toList();
    final centre = _viewCentre;
    final squash = math.cos(centre.lat * math.pi / 180);
    double far(Venue place) {
      final dLat = place.latitude - centre.lat;
      final dLon = (place.longitude - centre.lon) * squash;
      return dLat * dLat + dLon * dLon;
    }

    inView.sort((a, b) => far(a).compareTo(far(b)));
    return (inView.length, inView.take(_nearbyLimit).toList());
  }

  @override
  Widget build(BuildContext context) {
    _refreshLists();
    final venues = _clubs;
    final (inView, nearby) = _nearbyPlaces;
    final query = _searchController.text.trim();
    return Stack(
      children: [
        Column(
          children: [
            SkyHeader(
              title: context.l10n.search,
              subtitle: context.l10n.searchSubtitle,
              trailing: SkyIconButton(
                icon: AppIcons.locateFixed,
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
                  // Price, distance and what the club has: the same sheet
                  // as on the home screen, which this screen never offered.
                  SelectableChip(
                    key: const ValueKey('search-filters'),
                    label: _filters.isEmpty
                        ? context.l10n.filtersOpen
                        : '${context.l10n.filtersOpen} · ${_filters.count}',
                    selected: !_filters.isEmpty,
                    onTap: _openFilters,
                  ),
                  const SizedBox(width: 8),
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
                        selected: _sportId == sport.id,
                        color: AppTheme.sportGround(sport.id).last,
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
                        key: ValueKey(
                          'search-map-$_mapAttempt-'
                          '${Theme.of(context).brightness.name}',
                        ),
                        onStyleLoaded: (_) => _mapLoaded(),
                        onEvent: _onMapEvent,
                        options: maplibre.MapOptions(
                          initStyle: _mapStyleFor(Theme.of(context).brightness),
                          initCenter: _moscowCenter,
                          initZoom: _moscowZoom,
                          minZoom: 8,
                          maxZoom: 18,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        children: [
                          // Clubs and thousands of free courts, grouped
                          // into numbered circles until the map is close
                          // enough for each to have room of its own.
                          _ClusteredMarkers(
                            clubs: venues,
                            places: _places,
                            selectedId: _selectedVenue?.id,
                            sportOf: _sportForVenue,
                            onPick: _selectVenue,
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
                      if (_mapFailed)
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 12,
                          child: RetryNotice(
                            key: const ValueKey('search-map-failed'),
                            message: context.l10n.mapFailed,
                            onRetry: _retryMap,
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
                        nearby: nearby,
                        inView: inView,
                        sportOf: _sportForVenue,
                        selected: _selectedVenue,
                        query: query,
                        onPick: _openVenue,
                        onReset: () => setState(() {
                          _sportId = 'all';
                          _filters = VenueFilters.none;
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
    context.go(Routes.venue(venue.id));
  }

  void _selectVenue(Venue venue) {
    setState(() => _selectedVenue = venue);
    if (_sheetController.isAttached && _sheetController.size < _sheetOpen) {
      _sheetController.animateTo(
        _sheetOpen,
        duration: context.motion(const Duration(milliseconds: 260)),
        curve: Curves.easeOutCubic,
      );
    }
    _mapController?.animateCamera(
      center: venue.mapPoint,
      // A court sits among others: close enough that it stands alone.
      zoom: venue.isPublic ? _ClusteredMarkers.ownPinZoom : 12.8,
      nativeDuration: const Duration(milliseconds: 650),
      webMaxDuration: const Duration(milliseconds: 650),
      padding: const EdgeInsets.only(bottom: 160),
    );
  }

  /// The sport a club is shown as. Under a filter it is the filtered one —
  /// a club listed under "хоккей" drawing a football pitch reads as the
  /// wrong club.
  Sport? _sportForVenue(Venue venue) {
    final id = primarySportId(venue, filterId: _sportId);
    for (final sport in widget.controller.sports) {
      if (sport.id == id) {
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
          Icon(AppIcons.search, color: context.colors.muted),
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
                    AppIcons.x,
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
      child: TapTarget(
        onTap: onTap,
        radius: 16,
        child: AnimatedScale(
          duration: context.motion(const Duration(milliseconds: 180)),
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
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sport == null
                            ? context.colors.accent
                            : AppTheme.sportGround(sport!.id).last,
                      ),
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
    required this.nearby,
    required this.inView,
    required this.sportOf,
    required this.selected,
    required this.query,
    required this.onPick,
    required this.onReset,
  });

  final AppController controller;
  final DraggableScrollableController sheetController;
  final List<Venue> venues;

  /// Free courts in view, nearest first, and how many are in view in all.
  final List<Venue> nearby;
  final int inView;
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  width: 44,
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
                  venues.isEmpty && controller.venues.isNotEmpty
                      ? context.l10n.nothingFound
                      : context.l10n.venuesToChoose(venues.length),
                  style: context.text.titleSmall,
                ),
              ),
              const SizedBox(height: 10),
              if (controller.venues.isEmpty)
                EmptyState(
                  key: const ValueKey('search-no-clubs'),
                  icon: AppIcons.mapPinOff,
                  title: context.l10n.noClubsYet,
                  description: context.l10n.noClubsYetHint,
                )
              else if (venues.isEmpty)
                // An empty map is indistinguishable from a broken one, so
                // say which filter emptied it.
                EmptyState(
                  key: const ValueKey('search-empty'),
                  icon: query.isEmpty ? AppIcons.mapPinOff : AppIcons.searchX,
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
              if (nearby.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    context.l10n.openPlacesInView(inView),
                    key: const ValueKey('search-open-places'),
                    style: context.text.titleSmall,
                  ),
                ),
                const SizedBox(height: 10),
                for (final place in nearby)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VenueRow(
                      key: ValueKey('search-place-${place.id}'),
                      venue: place,
                      sport: sportOf(place),
                      selected: selected?.id == place.id,
                      color: context.colors.bgAlt,
                      onTap: () => onPick(place),
                    ),
                  ),
                if (inView > nearby.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                    child: Text(
                      context.l10n.openPlacesNearestHint,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.muted,
                      ),
                    ),
                  ),
              ],
              if (controller.openPlaces.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                  child: Text(
                    context.l10n.openDataCredit,
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

bool _inside(maplibre.LngLatBounds view, double lat, double lon) =>
    lat >= view.latitudeSouth &&
    lat <= view.latitudeNorth &&
    lon >= view.longitudeWest &&
    lon <= view.longitudeEast;

/// Clubs and free courts on the map, grouped while they would overlap.
///
/// At city scale six thousand pins are one smear nobody can tap. Points
/// close on screen become a circle with their number; tapping it moves in
/// until the group falls apart. From [ownPinZoom] every place has its own
/// pin. Clubs keep the big pin they always had; a court is a small dot, with
/// a grey ring when it is behind a school fence. Only what is in view is
/// built, so moving the map stays smooth.
class _ClusteredMarkers extends StatefulWidget {
  const _ClusteredMarkers({
    required this.clubs,
    required this.places,
    required this.selectedId,
    required this.sportOf,
    required this.onPick,
  });

  static const ownPinZoom = 16.0;

  final List<Venue> clubs;
  final List<Venue> places;
  final String? selectedId;
  final Sport? Function(Venue) sportOf;
  final ValueChanged<Venue> onPick;

  @override
  State<_ClusteredMarkers> createState() => _ClusteredMarkersState();
}

class _ClusteredMarkersState extends State<_ClusteredMarkers> {
  /// Groups per whole zoom level; worked out once for the current lists.
  final _byZoom = <int, List<MapCluster<Venue>>>{};

  @override
  void didUpdateWidget(_ClusteredMarkers old) {
    super.didUpdateWidget(old);
    if (!identical(old.clubs, widget.clubs) ||
        !identical(old.places, widget.places)) {
      _byZoom.clear();
    }
  }

  List<MapCluster<Venue>> _groupsAt(int zoom) {
    return _byZoom[zoom] ??= clusterPoints<Venue>(
      // Clubs first, so a group holding one is centred on it.
      [...widget.clubs, ...widget.places],
      latitude: (venue) => venue.latitude,
      longitude: (venue) => venue.longitude,
      zoom: zoom.toDouble(),
      radiusPx: zoom >= _ClusteredMarkers.ownPinZoom ? 0 : 56,
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = maplibre.MapCamera.maybeOf(context);
    final map = maplibre.MapController.maybeOf(context);
    if (camera == null || map == null) {
      return const SizedBox.shrink();
    }
    final zoom = math.max(0, math.min(22, camera.zoom.floor()));
    var groups = _groupsAt(zoom);
    try {
      final view = map.getVisibleRegion();
      // A margin around the view, so pins do not pop in at the edge.
      final padLat = (view.latitudeNorth - view.latitudeSouth) * 0.2;
      final padLon = (view.longitudeEast - view.longitudeWest) * 0.2;
      final wide = maplibre.LngLatBounds(
        longitudeWest: view.longitudeWest - padLon,
        longitudeEast: view.longitudeEast + padLon,
        latitudeSouth: view.latitudeSouth - padLat,
        latitudeNorth: view.latitudeNorth + padLat,
      );
      groups = groups
          .where((group) => _inside(wide, group.latitude, group.longitude))
          .toList();
    } on Object {
      // Not ready to say what is in view: draw them all this once.
    }
    return maplibre.WidgetLayer(
      allowInteraction: true,
      markers: [
        for (final group in groups) _markerFor(group, camera.zoom, map),
      ],
    );
  }

  maplibre.Marker _markerFor(
    MapCluster<Venue> group,
    double zoom,
    maplibre.MapController map,
  ) {
    final point = maplibre.Geographic(
      lon: group.longitude,
      lat: group.latitude,
    );
    if (!group.isSingle) {
      final count = group.items.length;
      final size = count < 10
          ? 38.0
          : count < 100
          ? 46.0
          : 54.0;
      return maplibre.Marker(
        point: point,
        size: Size.square(size),
        child: _ClusterBubble(
          count: count,
          size: size,
          hasClub: group.items.any((venue) => !venue.isPublic),
          onTap: () => map.animateCamera(
            center: point,
            zoom: math.min(zoom + 2, _ClusteredMarkers.ownPinZoom),
            nativeDuration: const Duration(milliseconds: 450),
            webMaxDuration: const Duration(milliseconds: 450),
          ),
        ),
      );
    }
    final venue = group.items.single;
    final selected = venue.id == widget.selectedId;
    if (!venue.isPublic) {
      return maplibre.Marker(
        point: venue.mapPoint,
        size: const Size(58, 64),
        alignment: Alignment.bottomCenter,
        child: _MapMarker(
          venue: venue,
          sport: widget.sportOf(venue),
          isSelected: selected,
          onTap: () => widget.onPick(venue),
        ),
      );
    }
    return maplibre.Marker(
      point: venue.mapPoint,
      size: const Size.square(44),
      child: _PlaceDot(
        venue: venue,
        sport: widget.sportOf(venue),
        isSelected: selected,
        onTap: () => widget.onPick(venue),
      ),
    );
  }
}

/// A numbered circle standing for courts and clubs too close to tell apart.
class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({
    required this.count,
    required this.size,
    required this.hasClub,
    required this.onTap,
  });

  final int count;
  final double size;

  /// A group with a club in it is filled, so clubs can be found from afar.
  final bool hasClub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = hasClub ? context.colors.accent : context.colors.surface;
    final ink = hasClub ? context.colors.onAccent : context.colors.accent;
    return Semantics(
      button: true,
      label: context.l10n.mapClusterLabel(count),
      excludeSemantics: true,
      child: TapTarget(
        onTap: onTap,
        radius: size / 2,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: context.colors.ink.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '$count',
            style: context.text.labelMedium?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A free court: a small dot in the colour of its game, inside a tap area
/// of 44 pt. A court behind a school fence gets a grey ring instead of the
/// accent one.
class _PlaceDot extends StatelessWidget {
  const _PlaceDot({
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
    final ring = venue.isRestricted
        ? context.colors.muted
        : context.colors.accent;
    final dot = isSelected ? 26.0 : 20.0;
    return Semantics(
      button: true,
      label: venue.isRestricted
          ? '${venue.name.capitalized}, ${context.l10n.restrictedPlace}'
          : venue.name.capitalized,
      excludeSemantics: true,
      child: TapTarget(
        onTap: onTap,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(const Duration(milliseconds: 180)),
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sport == null
                    ? context.colors.surface
                    : AppTheme.sportGround(sport!.id).last,
                border: Border.all(
                  color: isSelected ? context.colors.ink : ring,
                  width: isSelected ? 3 : 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.ink.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
