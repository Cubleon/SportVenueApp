import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.controller,
    required this.venue,
  });

  final AppController controller;
  final Venue venue;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late DateTime _date = DateTime(
    widget.controller.now.year,
    widget.controller.now.month,
    widget.controller.now.day,
  );
  int _duration = 60;
  int _hour = 20;
  int _players = 4;
  List<TimeSlot> _slots = const [];
  bool _slotsLoading = true;
  String? _slotsError;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  BookingDraft get _draft => BookingDraft(
    venue: widget.venue,
    date: _date,
    durationMinutes: _duration,
    startHour: _hour,
    players: _players,
    mode: PaymentMode.split,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _BookingHeader(
                    venue: widget.venue,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: VenueHero(venue: widget.venue, height: 138),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 1,
                    title: 'Дата',
                    child: _DatePickerRow(
                      now: widget.controller.now,
                      selected: _date,
                      onSelect: (date) {
                        setState(() => _date = date);
                        _loadSlots();
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 2,
                    title: 'Продолжительность',
                    child: _DurationPicker(
                      value: _duration,
                      onChanged: (value) {
                        setState(() => _duration = value);
                        _loadSlots();
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 3,
                    title: 'Время',
                    child: _TimeGrid(
                      slots: _slots,
                      isLoading: _slotsLoading,
                      error: _slotsError,
                      selectedHour: _hour,
                      onChanged: (hour) => setState(() => _hour = hour),
                      onRetry: _loadSlots,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 4,
                    title: 'Игроки',
                    child: Column(
                      children: [
                        _CounterRow(
                          value: _players,
                          min: widget.venue.capacityMin,
                          max: widget.venue.capacityMax,
                          onChanged: (value) =>
                              setState(() => _players = value),
                        ),
                        const SizedBox(height: 14),
                        AppCard(child: BookingSummaryRows(draft: _draft)),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 200)),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PinnedActionBar(
                child: Column(
                  children: [
                    PrimaryButton(
                      key: const ValueKey('pay-share'),
                      label:
                          'Оплатить свою часть · ${AppFormatters.money(_draft.sharePrice)}',
                      tone: ButtonTone.commit,
                      onPressed: _canContinue
                          ? () => _goToConfirm(PaymentMode.split)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      key: const ValueKey('pay-full'),
                      label:
                          'Забронировать целиком · ${AppFormatters.money(_draft.totalPrice)}',
                      tone: ButtonTone.neutral,
                      onPressed: _canContinue
                          ? () => _goToConfirm(PaymentMode.full)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canContinue =>
      !_slotsLoading &&
      _slotsError == null &&
      _slots.any((slot) => slot.hour == _hour && slot.isAvailable);

  Future<void> _loadSlots() async {
    setState(() {
      _slotsLoading = true;
      _slotsError = null;
    });
    try {
      final slots = await widget.controller.loadSlots(
        venue: widget.venue,
        day: _date,
        durationMinutes: _duration,
      );
      if (!mounted) {
        return;
      }
      final selectedStillAvailable = slots.any(
        (slot) => slot.hour == _hour && slot.isAvailable,
      );
      final firstAvailable = slots
          .where((slot) => slot.isAvailable)
          .firstOrNull;
      setState(() {
        _slots = slots;
        if (!selectedStillAvailable && firstAvailable != null) {
          _hour = firstAvailable.hour;
        }
        _slotsLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _slots = const [];
        _slotsLoading = false;
        _slotsError = widget.controller.messageFor(error);
      });
    }
  }

  void _goToConfirm(PaymentMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          controller: widget.controller,
          draft: _draft.copyWith(mode: mode),
        ),
      ),
    );
  }
}

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.controller,
    required this.draft,
  });

  final AppController controller;
  final BookingDraft draft;

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _accepted = true;
  bool _loading = false;

  int get _paymentAmount {
    return widget.draft.mode == PaymentMode.split
        ? widget.draft.sharePrice
        : widget.draft.totalPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 136),
              children: [
                _BookingNav(
                  title: 'Подтверждение',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                _BookingDetailsCard(draft: widget.draft),
                const SizedBox(height: 12),
                const _CancellationTermsCard(),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _accepted = !_accepted),
                  borderRadius: BorderRadius.circular(16),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _accepted,
                          activeColor: AppColors.accent,
                          onChanged: (value) =>
                              setState(() => _accepted = value ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Нажимая «Перейти к оплате», вы соглашаетесь с условиями сервиса и политикой конфиденциальности',
                              style: context.text.bodySmall?.copyWith(
                                color: AppColors.muted,
                                height: 1.42,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PinnedActionBar(
                child: Column(
                  children: [
                    PrimaryButton(
                      key: const ValueKey('confirm-payment'),
                      label:
                          'Перейти к оплате · ${AppFormatters.money(_paymentAmount)}',
                      tone: ButtonTone.commit,
                      isLoading: _loading,
                      onPressed: _accepted ? _pay : null,
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      key: const ValueKey('close-booking-checkout'),
                      label: 'Вернуться назад',
                      tone: ButtonTone.neutral,
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      await widget.controller.addBooking(widget.draft);
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, 'Оплата прошла, бронь создана');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, widget.controller.messageFor(error));
    }
  }
}

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.controller,
    required this.booking,
  });

  final AppController controller;
  final Booking booking;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final canCancel = widget.controller.canCancelBooking(widget.booking);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, canCancel ? 112 : 24),
              children: [
                _BookingNav(
                  title: 'Детали брони',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                _BookingDetailsCard(
                  draft: widget.booking.draft,
                  status: widget.booking.status,
                ),
                const SizedBox(height: 12),
                const _CancellationTermsCard(),
                if (!canCancel) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Text(
                      'Отменить бронь может только организатор',
                      style: context.text.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (canCancel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PinnedActionBar(
                  child: PrimaryButton(
                    key: const ValueKey('cancel-booking'),
                    label: 'Отменить бронь',
                    tone: ButtonTone.neutral,
                    isLoading: _loading,
                    onPressed: _loading ? null : _cancel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    setState(() => _loading = true);
    try {
      await widget.controller.cancelBooking(widget.booking);
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, 'Бронь отменена');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, widget.controller.messageFor(error));
    }
  }
}

class _BookingDetailsCard extends StatelessWidget {
  const _BookingDetailsCard({required this.draft, this.status});

  final BookingDraft draft;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Детали бронирования',
            style: context.text.labelLarge?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          BookingSummaryRows(draft: draft),
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(
              'Статус · $status',
              style: context.text.bodySmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CancellationTermsCard extends StatelessWidget {
  const _CancellationTermsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Условия отмены',
            style: context.text.labelLarge?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const _Bullet(
            text:
                'Если игра не набирает участников за 2 часа до начала, бронь отменяется автоматически',
          ),
          const _Bullet(
            text:
                'Если вы отменяете сами, средства возвращаются на счёт в течение 3 дней',
          ),
        ],
      ),
    );
  }
}

class _BookingHeader extends StatelessWidget {
  const _BookingHeader({required this.venue, required this.onBack});

  final Venue venue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.ink,
          ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Бронирование',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  venue.name.capitalized,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BookingNav extends StatelessWidget {
  const _BookingNav({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.ink,
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({
    required this.step,
    required this.title,
    required this.child,
  });

  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.now,
    required this.selected,
    required this.onSelect,
  });

  final DateTime now;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(now.year, now.month, now.day);
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final date = start.add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, selected);
          return GestureDetector(
            onTap: () => onSelect(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 54,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppFormatters.weekdayShort(date).toUpperCase(),
                    style: context.text.labelSmall?.copyWith(
                      color: isSelected
                          ? AppColors.onAccent.withValues(alpha: 0.85)
                          : AppColors.dim,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: context.text.titleMedium?.copyWith(
                      color: isSelected ? AppColors.onAccent : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: 14,
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = {60: '1 час', 90: '1.5 часа', 120: '2 часа'};
    return Row(
      children: values.entries.map((entry) {
        final selected = value == entry.key;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: entry.key == 120 ? 0 : 8),
            child: SelectableChip(
              label: entry.value,
              selected: selected,
              onTap: () => onChanged(entry.key),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.slots,
    required this.isLoading,
    required this.error,
    required this.selectedHour,
    required this.onChanged,
    required this.onRetry,
  });

  final List<TimeSlot> slots;
  final bool isLoading;
  final String? error;
  final int selectedHour;
  final ValueChanged<int> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return AppCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                error!,
                style: context.text.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (slots.isEmpty) {
      return Text(
        'На эту дату свободных слотов нет',
        style: context.text.bodySmall?.copyWith(color: AppColors.muted),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final selected = slot.hour == selectedHour;
        return GestureDetector(
          onTap: slot.isAvailable ? () => onChanged(slot.hour) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent
                  : slot.isAvailable
                  ? Colors.transparent
                  : AppColors.ink.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.accent
                    : slot.isAvailable
                    ? AppColors.ink.withValues(alpha: 0.12)
                    : AppColors.ink.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                slot.label,
                style: context.text.titleSmall?.copyWith(
                  color: selected
                      ? AppColors.onAccent
                      : slot.isAvailable
                      ? AppColors.ink
                      : AppColors.dim,
                  decoration: slot.isAvailable
                      ? null
                      : TextDecoration.lineThrough,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CounterButton(
          key: const ValueKey('players-minus'),
          icon: Icons.remove_rounded,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        Expanded(
          child: Text(
            '$value ${value == 1
                ? 'игрок'
                : value < 5
                ? 'игрока'
                : 'игроков'}',
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _CounterButton(
          key: const ValueKey('players-plus'),
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: enabled ? AppColors.accent : AppColors.surfaceRaised,
        disabledBackgroundColor: AppColors.surfaceRaised,
        foregroundColor: AppColors.onAccent,
        disabledForegroundColor: AppColors.dim,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds the actions pinned to the bottom of a flow.
///
/// Without a ground of its own, content scrolls up through a floating button
/// and both become unreadable; the fade above it keeps the join from looking
/// like a hard edge.
