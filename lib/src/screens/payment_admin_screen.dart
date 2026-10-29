import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../labels.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/shared_widgets.dart';

/// The payments admin's desk: transfers to find in the bank statement, and
/// money to send back.
///
/// Until the bank confirms payments by itself, a share becomes paid only
/// when the owner of the service finds the transfer. This is where that
/// happens, one share at a time, the most urgent first.
class PaymentAdminScreen extends StatefulWidget {
  const PaymentAdminScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PaymentAdminScreen> createState() => _PaymentAdminScreenState();
}

class _PaymentAdminScreenState extends State<PaymentAdminScreen> {
  ShareStatus _tab = ShareStatus.pendingConfirmation;
  late Future<List<PaymentQueueItem>> _queue;

  /// The share whose button was pressed, so only its card waits.
  String? _busy;

  @override
  void initState() {
    super.initState();
    _queue = _load();
  }

  Future<List<PaymentQueueItem>> _load() =>
      widget.controller.loadPaymentQueue(_tab);

  Future<void> _reload() async {
    final next = _load();
    setState(() => _queue = next);
    await next;
  }

  void _switch(ShareStatus tab) {
    if (tab == _tab) {
      return;
    }
    setState(() {
      _tab = tab;
      _queue = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: PullToRefresh(
          controller: widget.controller,
          also: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ScreenTitleBar(
                  title: l10n.adminPaymentsTitle,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      SelectableChip(
                        key: const ValueKey('admin-tab-check'),
                        label: l10n.adminTabCheck,
                        selected: _tab == ShareStatus.pendingConfirmation,
                        onTap: () => _switch(ShareStatus.pendingConfirmation),
                      ),
                      const SizedBox(width: 8),
                      SelectableChip(
                        key: const ValueKey('admin-tab-refund'),
                        label: l10n.adminTabRefund,
                        selected: _tab == ShareStatus.refundDue,
                        onTap: () => _switch(ShareStatus.refundDue),
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<PaymentQueueItem>>(
                future: _queue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final error = snapshot.error;
                  if (error != null) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RetryNotice(
                          message: errorText(context, error),
                          onRetry: _reload,
                        ),
                      ),
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: EmptyState(
                          key: const ValueKey('admin-empty'),
                          icon: AppIcons.checkCircle,
                          title: l10n.adminEmptyTitle,
                          description: _tab == ShareStatus.refundDue
                              ? l10n.adminEmptyRefund
                              : l10n.adminEmptyCheck,
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _QueueCard(
                        item: items[index],
                        now: DateTime.now(),
                        busy: _busy == items[index].shareId,
                        onFound: () => _confirm(items[index]),
                        onNotFound: () => _reject(items[index]),
                        onRefunded: () => _refunded(items[index]),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(PaymentQueueItem item) async {
    final ok = await confirmAction(
      context,
      title: context.l10n.adminConfirmTitle,
      message: context.l10n.adminConfirmMessage(
        item.userName,
        AppFormatters.money(item.amount),
        item.code,
      ),
      confirmLabel: context.l10n.adminFound,
      tone: ButtonTone.commit,
    );
    if (!ok || !mounted) {
      return;
    }
    await _act(item, () => widget.controller.confirmShare(item.shareId));
  }

  Future<void> _reject(PaymentQueueItem item) async {
    final note = await _askReason(context);
    if (note == null || !mounted) {
      return;
    }
    await _act(
      item,
      () => widget.controller.rejectShare(item.shareId, note: note),
    );
  }

  Future<void> _refunded(PaymentQueueItem item) async {
    final ok = await confirmAction(
      context,
      title: context.l10n.adminRefundTitle,
      message: context.l10n.adminRefundMessage(
        item.userName,
        AppFormatters.money(item.amount),
      ),
      confirmLabel: context.l10n.adminRefunded,
      tone: ButtonTone.commit,
    );
    if (!ok || !mounted) {
      return;
    }
    await _act(item, () => widget.controller.markShareRefunded(item.shareId));
  }

  Future<void> _act(PaymentQueueItem item, Future<void> Function() run) async {
    setState(() => _busy = item.shareId);
    try {
      await run();
      if (!mounted) {
        return;
      }
      showAppSnack(context, context.l10n.adminMarked, tone: SnackTone.done);
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }
}

/// Asks why the transfer was not found. The answer is shown to the player,
/// so it is one of a few plain reasons rather than free text.
Future<String?> _askReason(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final reasons = [
        l10n.adminRejectAmount,
        l10n.adminRejectCode,
        l10n.adminRejectMissing,
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.colors.ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.adminRejectTitle,
                style: sheetContext.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.adminRejectHint,
                style: sheetContext.text.bodyMedium?.copyWith(
                  color: sheetContext.colors.muted,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < reasons.length; i++) ...[
                PrimaryButton(
                  key: ValueKey('admin-reason-$i'),
                  label: reasons[i],
                  tone: ButtonTone.neutral,
                  onPressed: () => Navigator.pop(sheetContext, reasons[i]),
                ),
                const SizedBox(height: 10),
              ],
              PrimaryButton(
                label: l10n.cancel,
                tone: ButtonTone.neutral,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.item,
    required this.now,
    required this.busy,
    required this.onFound,
    required this.onNotFound,
    required this.onRefunded,
  });

  final PaymentQueueItem item;
  final DateTime now;
  final bool busy;
  final VoidCallback onFound;
  final VoidCallback onNotFound;
  final VoidCallback onRefunded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final refund = item.status == ShareStatus.refundDue;
    // Under an hour to the deadline, the check is the one to do first.
    final urgent =
        !refund && item.deadlineAt.difference(now) < const Duration(hours: 1);
    final muted = context.text.bodySmall?.copyWith(color: colors.muted);
    final phone = item.phone;
    final payer = item.payerName;
    final claimed = item.claimedAt;
    final note = item.note;

    return AppCard(
      key: ValueKey('admin-share-${item.shareId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  item.code,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                AppFormatters.money(item.amount),
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.userName,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (payer != null) Text(l10n.adminPayer(payer), style: muted),
          if (phone != null)
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: phone));
                if (context.mounted) {
                  showAppSnack(context, l10n.adminPhoneCopied);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  phone,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            l10n.adminGameAt(
              item.venueName.capitalized,
              AppFormatters.moment(item.startsAt),
            ),
            style: muted,
          ),
          if (!refund)
            Text(
              l10n.adminDeadline(AppFormatters.moment(item.deadlineAt)),
              style: muted?.copyWith(
                color: urgent ? colors.danger : colors.muted,
                fontWeight: urgent ? FontWeight.w700 : null,
              ),
            ),
          if (claimed != null)
            Text(l10n.adminClaimed(AppFormatters.moment(claimed)), style: muted),
          if (note != null && note.isNotEmpty) Text(note, style: muted),
          const SizedBox(height: 12),
          if (refund)
            PrimaryButton(
              key: ValueKey('admin-refunded-${item.shareId}'),
              label: l10n.adminRefunded,
              tone: ButtonTone.commit,
              isLoading: busy,
              onPressed: busy ? null : onRefunded,
            )
          else
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    key: ValueKey('admin-found-${item.shareId}'),
                    label: l10n.adminFound,
                    tone: ButtonTone.commit,
                    isLoading: busy,
                    onPressed: busy ? null : onFound,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    key: ValueKey('admin-not-found-${item.shareId}'),
                    label: l10n.adminNotFound,
                    tone: ButtonTone.neutral,
                    onPressed: busy ? null : onNotFound,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
