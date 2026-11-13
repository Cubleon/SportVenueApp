import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../models/sport_venue_models.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/venue_submission_details.dart';

class ModeratorDashboardScreen extends StatefulWidget {
  const ModeratorDashboardScreen({
    super.key,
    required this.api,
    required this.sports,
    required this.onLogout,
  });
  final SportVenueApiClient api;
  final List<Sport> sports;
  final VoidCallback onLogout;

  @override
  State<ModeratorDashboardScreen> createState() =>
      _ModeratorDashboardScreenState();
}

class _ModeratorDashboardScreenState extends State<ModeratorDashboardScreen> {
  ApiJsonList _submissions = [];
  bool _loading = true;
  String? _busyId;
  String? _error;
  String? _reviewErrorId;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busyId != null) return;
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
      _reviewErrorId = null;
    });
    try {
      final rows = await widget.api.listVenueSubmissions(moderation: true);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _submissions = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loading = false;
        _error = context.l10n.submissionsLoadFailed;
      });
    }
  }

  Future<void> _review(String id, bool approve) async {
    if (_busyId != null || _loading) return;
    setState(() {
      _busyId = id;
      _error = null;
      _reviewErrorId = null;
    });
    try {
      await widget.api.reviewVenueSubmission(id, approve: approve);
      if (!mounted) return;
      setState(() {
        _submissions.removeWhere((row) => row['id'] == id);
        _busyId = null;
      });
      showAppSnack(
        context,
        approve
            ? context.l10n.venueApproved
            : context.l10n.submissionRejectedSnack,
      );
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 409) {
        setState(() {
          _submissions.removeWhere((row) => row['id'] == id);
          _busyId = null;
        });
        showAppSnack(context, context.l10n.submissionAlreadyReviewed);
      } else {
        setState(() {
          _busyId = null;
          _reviewErrorId = id;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('moderator-dashboard'),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text(context.l10n.moderationQueueTitle),
      actions: [
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: _loading || _busyId != null ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const ValueKey('moderator-logout'),
          tooltip: context.l10n.signOutShort,
          onPressed: _busyId != null ? null : widget.onLogout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            RetryNotice(
              message: _error!,
              onRetry: () {
                if (_busyId == null) _load();
              },
            ),
            const SizedBox(height: 16),
          ],
          if (!_loading && _error == null && _submissions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  context.l10n.noSubmissionsToReview,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ),
            ),
          if (!_loading)
            for (final row in _submissions)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: AppCard(
                  key: ValueKey('submission-${row['id']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VenueSubmissionDetails(
                        submission: row,
                        sports: widget.sports,
                      ),
                      const SizedBox(height: 20),
                      if (_reviewErrorId == row['id'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            context.l10n.reviewSaveFailed,
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.error,
                            ),
                          ),
                        ),
                      if (_busyId == row['id'])
                        const Center(child: CircularProgressIndicator())
                      else
                        // The app's own pair, as on the payments queue:
                        // the decision filled, the refusal outlined.
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                key: ValueKey('approve-${row['id']}'),
                                label: context.l10n.approve,
                                tone: ButtonTone.commit,
                                onPressed: _busyId != null
                                    ? null
                                    : () => _review(row['id'] as String, true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PrimaryButton(
                                key: ValueKey('reject-${row['id']}'),
                                label: context.l10n.reject,
                                tone: ButtonTone.neutral,
                                onPressed: _busyId != null
                                    ? null
                                    : () => _review(row['id'] as String, false),
                              ),
                            ),
                          ],
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
