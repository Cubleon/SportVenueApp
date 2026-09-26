import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../router.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

/// What a club is, before deciding to pay for an hour of it.
///
/// Tapping a club used to open the payment screen. Everything the app knew
/// about the place — what it offers, what is there, what people made of it —
/// was either on the row that had just been tapped or nowhere, and the
/// rating it printed could not be read behind. Sixteen hundred roubles is
/// not a sum to spend on two lines of text.
class VenueScreen extends StatefulWidget {
  const VenueScreen({
    super.key,
    required this.controller,
    required this.venue,
    this.date,
  });

  final AppController controller;
  final Venue venue;

  /// The day the reader was looking at, carried through to booking.
  final DateTime? date;

  @override
  State<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<VenueScreen> {
  /// Free hours on [_day], or null while they are being counted.
  int? _freeHours;

  DateTime get _day => widget.date ?? DateUtils.dateOnly(widget.controller.now);

  @override
  void initState() {
    super.initState();
    _loadFreeHours();
  }

  Future<void> _loadFreeHours() async {
    final slots = await widget.controller.loadSlots(
      venue: widget.venue,
      day: _day,
      durationMinutes: 60,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _freeHours = slots.where((slot) => slot.isAvailable).length;
    });
  }

  Sport? _sportOf(String id) {
    for (final sport in widget.controller.sports) {
      if (sport.id == id) {
        return sport;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Row(
                    children: [
                      BackCircleButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      if (canShareLinks)
                        IconButton.filled(
                          key: const ValueKey('share-venue'),
                          tooltip: context.l10n.shareVenue,
                          onPressed: () =>
                              copyLink(context, Routes.venue(venue.id)),
                          icon: const Icon(AppIcons.share),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surface,
                            foregroundColor: colors.ink,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  VenueHero(
                    venue: venue,
                    height: context.scaled(168, max: 1.2),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    venue.name.capitalized,
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.venueAddressDistance(
                      venue.address,
                      venue.distanceKm.toStringAsFixed(1),
                    ),
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RatingRow(venue: venue),
                  if (venue.description.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      venue.description.capitalized,
                      style: context.text.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // What the club plays, as the same coloured chips the rest
                  // of the app uses for a sport.
                  if (venue.sportIds.isNotEmpty) ...[
                    _Label(text: context.l10n.venueSports),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in venue.sportIds)
                          SelectableChip(
                            label: _sportOf(id)?.name.capitalized ?? id,
                            selected: true,
                            color: AppTheme.sportGround(id).last,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (venue.amenities.isNotEmpty) ...[
                    _Label(text: context.l10n.venueAmenities),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final amenity in venue.amenities)
                          _Amenity(label: amenity),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  AppCard(
                    child: Column(
                      children: [
                        SummaryRow(
                          label: context.l10n.price,
                          value: context.l10n.pricePerHour(
                            AppFormatters.money(venue.pricePerHour),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // The day goes in the value, not the label: as a
                        // label it wraps to two lines against rows that are
                        // one, and the column stops looking like a column.
                        SummaryRow(
                          label: context.l10n.freeLabel,
                          value: _freeHours == null
                              ? context.l10n.loading
                              : '${context.l10n.hoursCount(_freeHours!)} · '
                                    '${AppFormatters.dateShort(_day)}',
                          accent: _freeHours != null && _freeHours! > 0,
                        ),
                        const SizedBox(height: 10),
                        SummaryRow(
                          label: context.l10n.venueCapacity,
                          value: context.l10n.capacityRange(
                            venue.capacityMin,
                            venue.capacityMax,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PrimaryButton(
                key: const ValueKey('venue-book'),
                label: context.l10n.bookVenueAction,
                onPressed: () =>
                    context.go(Routes.book(venue.id, date: widget.date)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final reviews = venue.reviewCount;
    return Semantics(
      label: reviews == null
          ? context.l10n.ratingOnly(venue.rating.toStringAsFixed(1))
          : context.l10n.ratingWithReviews(
              venue.rating.toStringAsFixed(1),
              reviews,
            ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(AppIcons.star, size: 17, color: context.colors.ink),
            const SizedBox(width: 6),
            Text(
              venue.rating.toStringAsFixed(1),
              style: AppTheme.numeric(
                context.text.titleMedium,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            if (reviews != null) ...[
              const SizedBox(width: 8),
              Text(
                context.l10n.reviewsCount(reviews),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTheme.eyebrow(context, context.colors.muted));
  }
}

class _Amenity extends StatelessWidget {
  const _Amenity({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: context.colors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.check, size: 15, color: context.colors.success),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
