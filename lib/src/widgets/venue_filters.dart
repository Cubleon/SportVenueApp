import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// What a reader has narrowed the club list down to.
///
/// The app had one filter — the sport — and two controls that promised more:
/// a sliders icon that opened the map, and a sliders icon that answered
/// "позже". On four clubs that is invisible; on a real catalogue it is the
/// only way to use the list at all.
///
/// Every field here is backed by something the catalogue actually holds. A
/// filter for a thing the data does not know is a filter that returns
/// nothing and cannot be explained.
@immutable
class VenueFilters {
  const VenueFilters({
    this.maxPrice,
    this.maxDistanceKm,
    this.amenities = const {},
  });

  /// The most the reader will pay per hour, or null for no ceiling.
  final int? maxPrice;

  /// How far they will go, or null for any distance.
  final double? maxDistanceKm;

  /// Everything the club must have. All of them, not any: a reader who ticks
  /// «крытая» and «душевые» wants both.
  final Set<String> amenities;

  static const none = VenueFilters();

  bool get isEmpty =>
      maxPrice == null && maxDistanceKm == null && amenities.isEmpty;

  /// How many of them are set, for the dot on the button.
  int get count =>
      (maxPrice == null ? 0 : 1) +
      (maxDistanceKm == null ? 0 : 1) +
      amenities.length;

  bool allows(Venue venue) {
    if (maxPrice != null && venue.pricePerHour > maxPrice!) {
      return false;
    }
    if (maxDistanceKm != null && venue.distanceKm > maxDistanceKm!) {
      return false;
    }
    for (final amenity in amenities) {
      if (!venue.amenities.contains(amenity)) {
        return false;
      }
    }
    return true;
  }

  VenueFilters copyWith({
    int? maxPrice,
    double? maxDistanceKm,
    Set<String>? amenities,
    bool clearPrice = false,
    bool clearDistance = false,
  }) {
    return VenueFilters(
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      maxDistanceKm: clearDistance
          ? null
          : (maxDistanceKm ?? this.maxDistanceKm),
      amenities: amenities ?? this.amenities,
    );
  }
}

/// Opens the filter sheet. Answers null if the reader backed out.
Future<VenueFilters?> showVenueFilters(
  BuildContext context, {
  required VenueFilters current,
  required List<Venue> venues,
}) {
  return showModalBottomSheet<VenueFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _FilterSheet(initial: current, venues: venues),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.venues});

  final VenueFilters initial;
  final List<Venue> venues;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late VenueFilters _draft = widget.initial;

  /// The bounds come from the catalogue, so a slider never offers a price
  /// nobody charges or a distance past the furthest club.
  late final int _minPrice = widget.venues.isEmpty
      ? 0
      : widget.venues
            .map((v) => v.pricePerHour)
            .reduce((a, b) => a < b ? a : b);
  late final int _maxPrice = widget.venues.isEmpty
      ? 0
      : widget.venues
            .map((v) => v.pricePerHour)
            .reduce((a, b) => a > b ? a : b);
  late final double _maxDistance = widget.venues.isEmpty
      ? 0
      : widget.venues.map((v) => v.distanceKm).reduce((a, b) => a > b ? a : b);

  late final List<String> _amenities = {
    for (final venue in widget.venues) ...venue.amenities,
  }.toList()..sort();

  int get _matches => widget.venues.where(_draft.allows).length;

  @override
  Widget build(BuildContext context) {
    final priceSpread = _maxPrice - _minPrice;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.filtersTitle,
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!_draft.isEmpty)
                  TextButton(
                    key: const ValueKey('filters-reset'),
                    onPressed: () => setState(() => _draft = VenueFilters.none),
                    child: Text(context.l10n.reset),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (priceSpread > 0) ...[
              _SliderBlock(
                title: context.l10n.filterPrice,
                value: _draft.maxPrice == null
                    ? context.l10n.filterAnyPrice
                    : context.l10n.upTo(
                        context.l10n.pricePerHour(
                          AppFormatters.money(_draft.maxPrice!),
                        ),
                      ),
                slider: Slider(
                  value: (_draft.maxPrice ?? _maxPrice).toDouble(),
                  min: _minPrice.toDouble(),
                  max: _maxPrice.toDouble(),
                  divisions: priceSpread <= 10 ? priceSpread : 10,
                  onChanged: (value) => setState(() {
                    final rounded = value.round();
                    _draft = rounded >= _maxPrice
                        ? _draft.copyWith(clearPrice: true)
                        : _draft.copyWith(maxPrice: rounded);
                  }),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (_maxDistance > 0) ...[
              _SliderBlock(
                title: context.l10n.filterDistance,
                value: _draft.maxDistanceKm == null
                    ? context.l10n.filterAnyDistance
                    : context.l10n.upTo(
                        context.l10n.distanceKm(
                          _draft.maxDistanceKm!.toStringAsFixed(1),
                        ),
                      ),
                slider: Slider(
                  value: _draft.maxDistanceKm ?? _maxDistance,
                  min: 0.5,
                  max: _maxDistance,
                  divisions: 10,
                  onChanged: (value) => setState(() {
                    _draft = value >= _maxDistance
                        ? _draft.copyWith(clearDistance: true)
                        : _draft.copyWith(maxDistanceKm: value);
                  }),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_amenities.isNotEmpty) ...[
              Text(
                context.l10n.filterAmenities,
                style: AppTheme.eyebrow(context, context.colors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amenity in _amenities)
                    SelectableChip(
                      label: amenity,
                      selected: _draft.amenities.contains(amenity),
                      onTap: () => setState(() {
                        final next = {..._draft.amenities};
                        if (!next.remove(amenity)) {
                          next.add(amenity);
                        }
                        _draft = _draft.copyWith(amenities: next);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            PrimaryButton(
              key: const ValueKey('filters-apply'),
              // The count is the point: a filter that leaves nothing should
              // say so before it is applied, not after.
              label: _matches == 0
                  ? context.l10n.filterNoMatches
                  : context.l10n.filterShow(_matches),
              onPressed: _matches == 0
                  ? null
                  : () => Navigator.pop(context, _draft),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderBlock extends StatelessWidget {
  const _SliderBlock({
    required this.title,
    required this.value,
    required this.slider,
  });

  final String title;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTheme.eyebrow(context, context.colors.muted),
              ),
            ),
            Text(
              value,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}
