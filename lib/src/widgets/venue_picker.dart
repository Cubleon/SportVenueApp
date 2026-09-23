import 'package:flutter/material.dart';

import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// Opens the club picker and answers with the chosen club, or null if the
/// sheet was dismissed.
///
/// A handful of clubs fit under a heading; a city's worth does not. The
/// list moves into a sheet with a field over it, so the step stays one line
/// tall however long the catalogue grows.
Future<Venue?> pickVenue(
  BuildContext context, {
  required List<Venue> venues,
  required Venue? selected,
  required Sport? Function(Venue) sportOf,
}) {
  return showModalBottomSheet<Venue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) =>
        _VenuePickerSheet(venues: venues, selected: selected, sportOf: sportOf),
  );
}

class _VenuePickerSheet extends StatefulWidget {
  const _VenuePickerSheet({
    required this.venues,
    required this.selected,
    required this.sportOf,
  });

  final List<Venue> venues;
  final Venue? selected;
  final Sport? Function(Venue) sportOf;

  @override
  State<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends State<_VenuePickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Venue> get _matches {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.venues;
    }
    return widget.venues
        .where(
          (venue) =>
              venue.name.toLowerCase().contains(query) ||
              venue.address.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Padding(
      // The keyboard takes the bottom of the screen; the list gives way to
      // it rather than hiding under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Площадка',
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: AppCard(
                  color: context.colors.bgAlt,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: context.colors.dim),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('venue-picker-search'),
                          controller: _query,
                          autofocus: false,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          style: context.text.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            hintText: 'Название или адрес',
                            hintStyle: context.text.bodyMedium?.copyWith(
                              color: context.colors.muted,
                            ),
                          ),
                        ),
                      ),
                      if (_query.text.isNotEmpty)
                        Semantics(
                          button: true,
                          label: 'Очистить',
                          child: InkWell(
                            key: const ValueKey('venue-picker-clear'),
                            onTap: () {
                              _query.clear();
                              setState(() {});
                            },
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
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
                ),
              ),
              Expanded(
                child: matches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: EmptyState(
                          key: const ValueKey('venue-picker-empty'),
                          icon: Icons.search_off_rounded,
                          title: 'Ничего не нашлось',
                          description:
                              'По запросу «${_query.text.trim()}» нет ни клуба, '
                              'ни адреса.',
                          actionLabel: 'Сбросить',
                          onAction: () {
                            _query.clear();
                            setState(() {});
                          },
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: matches.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final venue = matches[index];
                          final isSelected = venue.id == widget.selected?.id;
                          return VenueRow(
                            key: ValueKey('venue-option-${venue.id}'),
                            venue: venue,
                            sport: widget.sportOf(venue),
                            selected: isSelected,
                            color: context.colors.bgAlt,
                            onTap: () => Navigator.pop(context, venue),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: context.colors.accent,
                                  )
                                : const SizedBox(width: 24),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
