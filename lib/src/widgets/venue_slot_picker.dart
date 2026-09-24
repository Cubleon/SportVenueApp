import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../models/sport_venue_models.dart';
import '../labels.dart';
import '../theme/app_theme.dart';
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
  });

  final AppController controller;
  final Venue venue;
  final DateTime date;
  final int durationMinutes;
  final int selectedHour;

  /// Fires on a tap, and when a reload has to move the selection.
  final ValueChanged<int> onHourChanged;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onReadyChanged(ready);
      }
    });
  }

  Future<void> _load() async {
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
      if (!mounted) {
        return;
      }
      setState(() {
        _slots = slots;
        _loading = false;
      });
      final stillFree = slots.any(
        (slot) => slot.hour == widget.selectedHour && slot.isAvailable,
      );
      if (!stillFree) {
        final firstFree = slots.where((slot) => slot.isAvailable).firstOrNull;
        if (firstFree != null) {
          widget.onHourChanged(firstFree.hour);
        }
      }
      _reportReady(stillFree || slots.any((slot) => slot.isAvailable));
    } catch (error) {
      if (!mounted) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: context.scaled(52),
        child: const Center(child: CircularProgressIndicator()),
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
            selected: slot.hour == widget.selectedHour,
            available: slot.isAvailable,
            onTap: () {
              widget.onHourChanged(slot.hour);
              _reportReady(true);
            },
          ),
      ],
    );
  }
}
