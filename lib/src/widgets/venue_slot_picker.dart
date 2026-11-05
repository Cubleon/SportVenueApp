import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../models/sport_venue_models.dart';
import '../labels.dart';
import '../theme/app_theme.dart';
import 'skeleton.dart';
import 'shared_widgets.dart';

/// The hours a particular club has free on a particular day, and the one
/// that has been picked.
///
/// Availability belongs to the club, not to the clock: two venues on the
/// same evening have different free hours, and offering a fixed range of
/// them invites a game nobody can actually hold. So the picker asks the
/// club, shows what came back, strikes through what is taken, and moves the
/// selection off an hour that has stopped being available.
class VenueSlotPicker extends StatefulWidget {
  const VenueSlotPicker({
    super.key,
    required this.controller,
    required this.venue,
    required this.date,
    required this.durationMinutes,
    required this.selectedHour,
    required this.onHourChanged,
    required this.onReadyChanged,
    this.selectedMinute = 0,
    this.onSlotChanged,
  });

  final AppController controller;
  final Venue venue;
  final DateTime date;
  final int durationMinutes;
  final int selectedHour;
  final int selectedMinute;

  /// Fires on a tap, and when a reload has to move the selection.
  final ValueChanged<int> onHourChanged;

  /// Includes the minute and exact API instant for published half-hour starts.
  final ValueChanged<TimeSlot>? onSlotChanged;

  /// Whether the picked hour is one the club will actually take. The screen
  /// gates its own button on this rather than guessing.
  final ValueChanged<bool> onReadyChanged;

  @override
  State<VenueSlotPicker> createState() => _VenueSlotPickerState();
}

class _VenueSlotPickerState extends State<VenueSlotPicker> {
  List<TimeSlot> _slots = const [];
  bool _loading = true;
  Object? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VenueSlotPicker old) {
    super.didUpdateWidget(old);
    if (old.venue.id != widget.venue.id ||
        !DateUtils.isSameDay(old.date, widget.date) ||
        old.durationMinutes != widget.durationMinutes) {
      _load();
    }
  }

  /// Tells the screen whether the hour on screen is takeable.
  ///
  /// Deferred by a frame on purpose: a reload starts from [initState] and
  /// [didUpdateWidget], where the screen above is already building and
  /// cannot be marked dirty again.
  void _reportReady(bool ready) {
    final generation = _loadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _loadGeneration) {
        widget.onReadyChanged(ready);
      }
    });
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    _reportReady(false);
    try {
      final slots = await widget.controller.loadSlots(
        venue: widget.venue,
        day: widget.date,
        durationMinutes: widget.durationMinutes,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _slots = slots;
        _loading = false;
      });
      final selected =
          slots
              .where((slot) => _isSelected(slot) && slot.isAvailable)
              .firstOrNull ??
          slots.where((slot) => slot.isAvailable).firstOrNull;
      if (selected != null) {
        _select(selected);
      }
      _reportReady(selected != null);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _slots = const [];
        _loading = false;
        _error = error;
      });
      _reportReady(false);
    }
  }

  bool _isSelected(TimeSlot slot) =>
      slot.hour == widget.selectedHour && slot.minute == widget.selectedMinute;

  void _select(TimeSlot slot) {
    widget.onHourChanged(slot.hour);
    widget.onSlotChanged?.call(slot);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // The shape of the answer, not a spinner: the grid that is coming,
      // in the size it will be, so nothing jumps when it lands.
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < 8; i++)
            Skeleton(
              width: context.scaled(84, max: 1.3),
              height: context.scaled(48, max: 1.3),
              radius: AppTheme.radiusInner,
            ),
        ],
      );
    }
    if (_error != null) {
      return AppCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                errorText(context, _error!),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ),
            TextButton(onPressed: _load, child: Text(context.l10n.retry)),
          ],
        ),
      );
    }
    if (_slots.isEmpty) {
      return Text(
        context.l10n.noFreeSlots,
        style: context.text.bodySmall?.copyWith(color: context.colors.muted),
      );
    }
    return TimeGrid(
      tiles: [
        for (final slot in _slots)
          TimeTile(
            label: slot.label,
            selected: _isSelected(slot),
            available: slot.isAvailable,
            onTap: () {
              _select(slot);
              _reportReady(true);
            },
          ),
      ],
    );
  }
}
