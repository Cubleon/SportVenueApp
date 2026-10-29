import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../labels.dart';
import '../models/sport_venue_models.dart';
import '../router.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

/// Paying the reader's share of a booking.
///
/// On the pilot money moves outside the app: the reader opens their bank by
/// the SBP link (or scans the QR from another phone), pays the amount with
/// the share's code in the comment, and says so with «Я оплатил». The share
/// is paid only when the payments admin finds the transfer, and the screen
/// says which of those it is waiting for.
class SharePaymentScreen extends StatefulWidget {
  const SharePaymentScreen({
    super.key,
    required this.controller,
    required this.bookingId,
    this.justCreated = false,
    this.openLink,
  });

  final AppController controller;
  final String bookingId;

  /// The booking was made a moment ago: the screen opens by saying so, and
  /// by telling the organiser what the others still owe.
  final bool justCreated;

  /// Opens the bank. Tests pass their own; the app uses the platform's.
  final Future<bool> Function(Uri uri)? openLink;

  @override
  State<SharePaymentScreen> createState() => _SharePaymentScreenState();
}

class _SharePaymentScreenState extends State<SharePaymentScreen> {
  /// Measured, because the bar's buttons grow with the system font.
  double _barHeight = 150;

  late Future<PaymentInfo> _info = widget.controller.loadPaymentInfo();
  bool _claiming = false;

  void _onBarHeight(double height) {
    if (mounted && height != _barHeight) {
      setState(() => _barHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final booking = widget.controller.bookingById(widget.bookingId);
        final share = booking?.myShare;
        final needsPayment =
            share != null &&
            (share.status == ShareStatus.unpaid ||
                share.status == ShareStatus.notFound);
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    needsPayment ? _barHeight : 24,
                  ),
                  children: [
                    ScreenTitleBar(
                      padding: EdgeInsets.zero,
                      title: context.l10n.paymentScreenTitle,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 12),
                    if (booking == null || share == null)
                      _Notice(icon: AppIcons.x, title: context.l10n.payNothing)
                    else
                      ..._body(context, booking, share, needsPayment),
                  ],
                ),
                if (needsPayment)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PinnedActionBar(
                      onHeight: _onBarHeight,
                      child: Column(
                        children: [
                          PrimaryButton(
                            key: const ValueKey('pay-via-bank'),
                            label: context.l10n.payViaBank,
                            tone: ButtonTone.commit,
                            onPressed: _openBank,
                          ),
                          const SizedBox(height: 10),
                          PrimaryButton(
                            key: const ValueKey('claim-paid'),
                            label: context.l10n.payIPaid,
                            tone: ButtonTone.neutral,
                            isLoading: _claiming,
                            onPressed: _claiming
                                ? null
                                : () => _claim(booking!, share),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(
    BuildContext context,
    Booking booking,
    BookingShare share,
    bool needsPayment,
  ) {
    final amount = share.amount ?? booking.draft.sharePrice;
    final draft = booking.draft;
    return [
      if (widget.justCreated) ...[
        Text(
          context.l10n.bookingCreated,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (booking.othersUnpaid > 0) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.bookingCreatedShares(booking.othersUnpaid),
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.muted,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.payYourShare,
              style: AppTheme.sectionLabel(context),
            ),
            const SizedBox(height: 6),
            Text(
              AppFormatters.money(amount),
              key: const ValueKey('pay-amount'),
              style: AppTheme.numeric(
                context.text.headlineMedium,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${draft.venue.name.capitalized} · '
              '${AppFormatters.dateShort(draft.date)} · ${draft.timeRange}',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.muted,
              ),
            ),
            if (needsPayment || share.status == ShareStatus.pendingConfirmation)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.l10n.payDeadline(_moment(booking.deadline)),
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            FutureBuilder<PaymentInfo>(
              future: _info,
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.payRecipient(
                        info.recipientName,
                        info.bankName,
                      ),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.muted,
                      ),
                    ),
                    if (info.isTest) ...[
                      const SizedBox(height: 12),
                      _TestBanner(text: context.l10n.payTestBanner),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ..._status(context, share),
      if (needsPayment || share.status == ShareStatus.pendingConfirmation) ...[
        _CodeCard(code: share.code),
        const SizedBox(height: 12),
      ],
      if (needsPayment)
        FutureBuilder<PaymentInfo>(
          future: _info,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return RetryNotice(
                key: const ValueKey('payment-info-failed'),
                message: errorText(context, snapshot.error!),
                onRetry: () => setState(() {
                  _info = widget.controller.loadPaymentInfo();
                }),
              );
            }
            final info = snapshot.data;
            if (info == null) {
              return const SizedBox(height: 48);
            }
            return _QrCard(payload: info.qrPayload);
          },
        ),
      if (widget.justCreated) ...[
        const SizedBox(height: 12),
        PrimaryButton(
          key: const ValueKey('open-created-booking'),
          label: context.l10n.payToBooking,
          tone: ButtonTone.neutral,
          onPressed: () => context.go(Routes.booking(booking.id)),
        ),
      ],
    ];
  }

  /// What the share is waiting for, said once above the details.
  List<Widget> _status(BuildContext context, BookingShare share) {
    final l10n = context.l10n;
    final notice = switch (share.status) {
      ShareStatus.pendingConfirmation => _Notice(
        key: const ValueKey('pay-pending'),
        icon: AppIcons.clock,
        title: l10n.payPendingTitle,
        body: l10n.payPendingBody,
      ),
      ShareStatus.paid => _Notice(
        key: const ValueKey('pay-paid'),
        icon: AppIcons.checkCircle,
        tone: context.colors.success,
        title: l10n.payPaidTitle,
        body: l10n.payPaidBody,
      ),
      ShareStatus.notFound => _Notice(
        key: const ValueKey('pay-not-found'),
        icon: AppIcons.x,
        tone: context.colors.warning,
        title: l10n.payNotFoundTitle,
        body: [
          l10n.payNotFoundBody,
          if (share.note case final String note) l10n.payAdminNote(note),
        ].join('\n'),
      ),
      ShareStatus.refundDue => _Notice(
        icon: AppIcons.clock,
        title: l10n.payRefundDue,
      ),
      ShareStatus.refunded => _Notice(
        icon: AppIcons.checkCircle,
        title: l10n.payRefunded,
      ),
      ShareStatus.unpaid || ShareStatus.open => null,
    };
    return notice == null ? const [] : [notice, const SizedBox(height: 12)];
  }

  Future<void> _openBank() async {
    final l10n = context.l10n;
    PaymentInfo info;
    try {
      info = await _info;
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          errorText(context, error),
          tone: SnackTone.failed,
        );
      }
      return;
    }
    final uri = Uri.tryParse(info.sbpLink);
    var opened = false;
    if (uri != null) {
      try {
        opened =
            await (widget.openLink?.call(uri) ??
                launchUrl(uri, mode: LaunchMode.externalApplication));
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      showAppSnack(context, l10n.payBankFailed, tone: SnackTone.failed);
    }
  }

  Future<void> _claim(Booking booking, BookingShare share) async {
    setState(() => _claiming = true);
    try {
      await widget.controller.claimSharePaid(booking, share);
      // Not awaited: a platform that never answers must not hold the
      // screen on a claim that has already gone through.
      unawaited(HapticFeedback.mediumImpact());
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          errorText(context, error),
          tone: SnackTone.failed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claiming = false);
      }
    }
  }
}

/// A day and an hour, the way the rest of the app writes them.
String _moment(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '${AppFormatters.dateShort(value)}, $hours:$minutes';
}

/// The share's code, set large enough to copy by eye, with a button that
/// copies it for the reader: it goes into the transfer's comment, and a
/// transfer without it is a transfer the admin cannot match.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final value = code;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.payCodeLabel,
            style: AppTheme.sectionLabel(context),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  value ?? context.l10n.emptyValue,
                  key: const ValueKey('pay-code'),
                  style: AppTheme.numeric(
                    context.text.headlineSmall,
                  ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
              if (value != null)
                TextButton(
                  key: const ValueKey('copy-code'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (context.mounted) {
                      showAppSnack(
                        context,
                        context.l10n.payCodeCopied,
                        tone: SnackTone.done,
                      );
                    }
                  },
                  child: Text(context.l10n.payCopyCode),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.payCodeHint,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The QR, folded away under one quiet line.
///
/// On the phone that holds the app the bank button is the way to pay, and
/// the code it encodes is the same link. The QR is for the other cases: the
/// app open in a browser on a computer, or someone paying from another
/// phone. Drawn dark on white in both themes, since bank scanners read
/// that and not every one of them reads a light code on a dark page.
class _QrCard extends StatefulWidget {
  const _QrCard({required this.payload});

  final String payload;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          TextButton.icon(
            key: const ValueKey('toggle-qr'),
            onPressed: () => setState(() => _shown = !_shown),
            icon: Icon(_shown ? AppIcons.chevronDown : AppIcons.chevronRight),
            label: Text(
              _shown ? context.l10n.payQrHide : context.l10n.payQrShow,
            ),
          ),
          if (_shown) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusInner),
              ),
              child: QrImageView(
                key: const ValueKey('pay-qr'),
                data: widget.payload,
                size: 188,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
                semanticsLabel: context.l10n.payQrHint,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.payQrHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.muted,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Says plainly that this payment is not real, in the colour the app keeps
/// for things to watch.
class _TestBanner extends StatelessWidget {
  const _TestBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.warning;
    return Container(
      key: const ValueKey('pay-test-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.ink,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? context.colors.accent;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
