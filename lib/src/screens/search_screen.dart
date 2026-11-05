import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre/maplibre.dart' as maplibre;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../router.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/sky_header.dart';

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
  String? _selectedVenueId;
  maplibre.MapController? _mapController;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Venue> get _venues {
    final query = _searchController.text.trim().toLowerCase();
    return widget.controller.venues.where((venue) {
      if (_sportId != 'all' && !venue.sportIds.contains(_sportId)) return false;
      return query.isEmpty ||
          venue.name.toLowerCase().contains(query) ||
          venue.address.toLowerCase().contains(query);
    }).toList();
  }

  void _selectSport(String id) => setState(() {
    _sportId = id;
    _selectedVenueId = null;
  });

  void _closePreview() => setState(() => _selectedVenueId = null);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final venues = _venues;
        final selected = venues
            .where((venue) => venue.id == _selectedVenueId)
            .firstOrNull;
        return Column(
          key: const ValueKey('search-screen'),
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
                onChanged: (_) => _closePreview(),
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
                    onTap: () => _selectSport('all'),
                  ),
                  const SizedBox(width: 8),
                  ...widget.controller.sports.map(
                    (sport) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectableChip(
                        label: sport.name.capitalized,
                        selected: _sportId == sport.id,
                        color: AppTheme.sportGround(sport.id).last,
                        onTap: () => _selectSport(sport.id),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final previewHeight = constraints.maxHeight * 0.55;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          maplibre.MapLibreMap(
                            key: const ValueKey('clubs-map'),
                            options: const maplibre.MapOptions(
                              initStyle: _mapStyle,
                              initCenter: _moscowCenter,
                              initZoom: _moscowZoom,
                              minZoom: 8,
                              maxZoom: 18,
                            ),
                            onMapCreated: (controller) =>
                                _mapController = controller,
                            onEvent: (event) {
                              if (event is maplibre.MapEventClick &&
                                  selected != null) {
                                _closePreview();
                              }
                            },
                            children: [
                              maplibre.WidgetLayer(
                                allowInteraction: true,
                                markers: venues
                                    .map(
                                      (venue) => maplibre.Marker(
                                        point: venue.mapPoint,
                                        size: const Size.square(48),
                                        child: _MapDot(
                                          key: ValueKey('club-dot-${venue.id}'),
                                          venue: venue,
                                          isSelected: selected?.id == venue.id,
                                          onTap: () => _selectVenue(
                                            venue,
                                            previewHeight,
                                          ),
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
                                  border: Border.all(
                                    color: context.colors.border,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (selected != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 30,
                              child: PointerInterceptor(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: previewHeight,
                                  ),
                                  child: _VenuePreview(
                                    venue: selected,
                                    onClose: _closePreview,
                                    onOpen: () =>
                                        context.go(Routes.venue(selected.id)),
                                  ),
                                ),
                              ),
                            ),
                          if (venues.isEmpty)
                            Positioned(
                              left: 12,
                              right: 12,
                              top: 12,
                              child: PointerInterceptor(
                                child: AppCard(
                                  key: const ValueKey('search-empty'),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _searchController.text.trim().isEmpty
                                            ? context.l10n.noVenuesForSport
                                            : context.l10n.nothingFound,
                                        style: context.text.titleSmall,
                                      ),
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _searchController.clear();
                                          _sportId = 'all';
                                          _selectedVenueId = null;
                                        }),
                                        child: Text(context.l10n.resetSearch),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectVenue(Venue venue, double previewHeight) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedVenueId = venue.id);
    _mapController?.animateCamera(
      center: venue.mapPoint,
      zoom: math.max(_mapController?.camera?.zoom ?? _moscowZoom, 12.8),
      nativeDuration: const Duration(milliseconds: 650),
      webMaxDuration: const Duration(milliseconds: 650),
      padding: EdgeInsets.only(bottom: previewHeight + 30),
    );
  }

  Future<void> _focusMoscow() async {
    _closePreview();
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
      padding: EdgeInsets.zero,
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
          Icon(AppIcons.search, color: context.colors.dim),
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

class _MapDot extends StatelessWidget {
  const _MapDot({
    super.key,
    required this.venue,
    required this.isSelected,
    required this.onTap,
  });

  final Venue venue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: venue.name.capitalized,
      child: TapTarget(
        onTap: onTap,
        radius: 24,
        child: Center(
          child: AnimatedContainer(
            duration: context.motion(const Duration(milliseconds: 180)),
            width: isSelected ? 22 : 16,
            height: isSelected ? 22 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.accent,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VenuePreview extends StatelessWidget {
  const _VenuePreview({
    required this.venue,
    required this.onClose,
    required this.onOpen,
  });

  final Venue venue;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        key: ValueKey('club-preview-${venue.id}'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    venue.name.capitalized,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-club-preview'),
                  tooltip: context.l10n.closeVenuePreview,
                  onPressed: onClose,
                  icon: const Icon(AppIcons.x),
                ),
              ],
            ),
            Text(
              venue.address,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  venue.isPublic
                      ? 'Общественная площадка'
                      : context.l10n.ratingOnly(
                          venue.rating.toStringAsFixed(1),
                        ),
                  style: context.text.bodySmall,
                ),
                Text(
                  venue.isPublic
                      ? 'Бесплатно'
                      : context.l10n.pricePerHour(
                          AppFormatters.money(venue.pricePerHour),
                        ),
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (venue.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                venue.description.capitalized,
                style: context.text.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              key: const ValueKey('open-club-details'),
              label: context.l10n.venueDetails,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

extension _VenueMapPoint on Venue {
  maplibre.Geographic get mapPoint =>
      maplibre.Geographic(lon: longitude, lat: latitude);
}
