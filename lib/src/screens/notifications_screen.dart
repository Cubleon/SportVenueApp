import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../router.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/shared_widgets.dart';

/// What the bell holds: what happened to the reader's games and bookings
/// while they were away, newest first. Each one leads to what it is about.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// What was new when the screen opened. Opening marks everything read, so
  /// the dots are taken from here, not from the notices themselves — or they
  /// would vanish the moment the reader arrived to look at them.
  late final Set<String> _fresh = {
    for (final note in widget.controller.notifications)
      if (!note.read) note.id,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.markNotificationsRead();
      }
    });
  }

  void _open(AppNotification note) {
    final gameId = note.gameId;
    final bookingId = note.bookingId;
    if (gameId != null) {
      context.go(Routes.game(gameId));
    } else if (bookingId != null) {
      context.go(Routes.booking(bookingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final notes = widget.controller.notifications;
        return Scaffold(
          body: SafeArea(
            child: PullToRefresh(
              controller: widget.controller,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenTitleBar(
                      title: context.l10n.notifications,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (notes.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: EmptyState(
                          key: const ValueKey('notifications-empty'),
                          icon: AppIcons.bell,
                          title: context.l10n.noNotifications,
                          description: context.l10n.noNotificationsHint,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.separated(
                        itemCount: notes.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return _NoteCard(
                            note: note,
                            fresh: _fresh.contains(note.id),
                            onTap: note.gameId == null && note.bookingId == null
                                ? null
                                : () => _open(note),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.fresh, this.onTap});

  final AppNotification note;
  final bool fresh;
  final VoidCallback? onTap;

  IconData get _icon => switch (note.kind) {
    NotificationKind.requestApproved ||
    NotificationKind.newRequest ||
    NotificationKind.requestRejected => AppIcons.volleyball,
    NotificationKind.gameCancelled ||
    NotificationKind.bookingCancelled => AppIcons.x,
    NotificationKind.payReminder => AppIcons.clock,
    NotificationKind.shareConfirmed ||
    NotificationKind.refunded => AppIcons.checkCircle,
    NotificationKind.other => AppIcons.bell,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: onTap != null,
      child: AppCard(
        key: ValueKey('note-${note.id}'),
        onTap: onTap,
        borderColor: fresh ? colors.accent : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, size: 20, color: colors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (fresh) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          label: context.l10n.notificationNew,
                          child: Container(
                            key: const ValueKey('note-fresh'),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (note.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.body,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    AppFormatters.moment(note.createdAt),
                    style: context.text.labelSmall?.copyWith(color: colors.dim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
