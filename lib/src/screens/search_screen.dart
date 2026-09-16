import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
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

  List<Venue> get _venues {
    if (_sportId == 'all') {
      return widget.controller.venues;
    }
    return widget.controller.venues
        .where((venue) => venue.sportIds.contains(_sportId))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final venues = _venues;
    return Stack(
      children: [
        Column(
          children: [
            ScreenTitleBar(
              title: 'Поиск',
              subtitle: 'Москва · openfreemap',
              trailing: IconButton(
                onPressed: _focusMoscow,
                icon: const Icon(Icons.my_location_rounded),
              ),
            ),
            _SearchField(),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  SelectableChip(
                    label: 'Все',
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
                        color: sport.color,
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 118),
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
                              border: Border.all(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: _MapPill(text: '${venues.length} клубов рядом'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedVenue != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: 108,
            child: _VenueBottomSheet(
              venue: _selectedVenue!,
              controller: widget.controller,
              onClose: () => setState(() => _selectedVenue = null),
            ),
          ),
      ],
    );
  }

  void _selectVenue(Venue venue) {
    setState(() => _selectedVenue = venue);
    _mapController?.animateCamera(
      center: venue.mapPoint,
      zoom: 12.8,
      nativeDuration: const Duration(milliseconds: 650),
      webMaxDuration: const Duration(milliseconds: 650),
      padding: const EdgeInsets.only(bottom: 160),
    );
  }

  Sport? _sportForVenue(Venue venue) {
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
      showAppSnack(context, 'Карта загружается');
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

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.dim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Клуб, площадка или район',
                style: context.text.bodyMedium?.copyWith(color: AppColors.dim),
              ),
            ),
            const Icon(Icons.tune_rounded, color: AppColors.accent),
          ],
        ),
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
        ? sport?.color ?? AppColors.accent
        : AppColors.accent;
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
                      color: AppColors.white.withValues(alpha: 0.32),
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
                          color: AppColors.white.withValues(alpha: 0.22),
                          width: 2,
                        ),
                        bottom: BorderSide(
                          color: AppColors.white.withValues(alpha: 0.22),
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

class _MapPill extends StatelessWidget {
  const _MapPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _VenueBottomSheet extends StatelessWidget {
  const _VenueBottomSheet({
    required this.venue,
    required this.controller,
    required this.onClose,
  });

  final Venue venue;
  final AppController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.accent.withValues(alpha: 0.2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  venue.name.capitalized,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            venue.address,
            style: context.text.bodySmall?.copyWith(color: AppColors.dim),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 17,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                '${venue.rating}',
                style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${AppFormatters.money(venue.pricePerHour)}/час',
                style: context.text.labelLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Подробнее и бронь',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    BookingScreen(controller: controller, venue: venue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
