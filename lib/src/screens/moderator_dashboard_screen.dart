import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../models/sport_venue_models.dart';
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
        _error = 'Не удалось загрузить заявки. Попробуйте ещё раз.';
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
            ? 'Площадка одобрена и добавлена на карту.'
            : 'Заявка отклонена.',
      );
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 409) {
        setState(() {
          _submissions.removeWhere((row) => row['id'] == id);
          _busyId = null;
        });
        showAppSnack(context, 'Заявка уже рассмотрена другим модератором.');
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
      title: const Text('Заявки на площадки'),
      actions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: _loading || _busyId != null ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const ValueKey('moderator-logout'),
          tooltip: 'Выйти',
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
            Text(_error!, style: TextStyle(color: context.colors.error)),
            TextButton(
              onPressed: _busyId == null ? _load : null,
              child: const Text('Обновить заявки'),
            ),
            const SizedBox(height: 16),
          ],
          if (!_loading && _error == null && _submissions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Нет заявок на модерацию')),
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
                            'Не удалось сохранить решение. Попробуйте ещё раз.',
                            style: TextStyle(color: context.colors.error),
                          ),
                        ),
                      if (_busyId == row['id'])
                        const Center(child: CircularProgressIndicator())
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              key: ValueKey('approve-${row['id']}'),
                              icon: const Icon(Icons.check),
                              label: const Text('Одобрить'),
                              onPressed: _busyId != null
                                  ? null
                                  : () => _review(row['id'] as String, true),
                            ),
                            OutlinedButton.icon(
                              key: ValueKey('reject-${row['id']}'),
                              icon: const Icon(Icons.close),
                              label: const Text('Отклонить'),
                              onPressed: _busyId != null
                                  ? null
                                  : () => _review(row['id'] as String, false),
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
