import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../../l10n/l10n.dart';
import '../data/api_client.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/location_picker.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/venue_submission_details.dart';

class VenueSubmissionsScreen extends StatefulWidget {
  const VenueSubmissionsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<VenueSubmissionsScreen> createState() => _VenueSubmissionsScreenState();
}

class _VenueSubmissionsScreenState extends State<VenueSubmissionsScreen> {
  ApiJsonList _submissions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = widget.controller.apiClient;
      // The demo has no server and so no submissions: an empty list, not a
      // red failure on a screen that has done nothing wrong.
      final rows = api == null
          ? <ApiJsonObject>[]
          : await api.listVenueSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.submissionsLoadFailed;
      });
    }
  }

  Future<void> _add() async {
    final api = widget.controller.apiClient;
    if (api == null) {
      showAppSnack(context, context.l10n.submissionNeedsServer);
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PublicVenueSubmissionScreen(
          api: api,
          sports: widget.controller.sports,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    showAppSnack(context, context.l10n.submissionSent, tone: SnackTone.done);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('venue-submissions-screen'),
    appBar: AppBar(
      title: Text(context.l10n.mySubmissionsTitle),
      actions: [
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          PrimaryButton(
            key: const ValueKey('add-public-venue'),
            label: context.l10n.addPublicVenueLong,
            icon: Icons.add_location_alt_outlined,
            onPressed: _add,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.publicVenueIntro,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            RetryNotice(
              key: const ValueKey('submissions-load-failed'),
              message: _error!,
              onRetry: _load,
            ),
          if (!_loading && _error == null && _submissions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.l10n.noSubmissionsYet,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ),
          if (!_loading && _error == null)
            for (final row in _submissions)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The same plaque a booking's status uses.
                      InfoTag(
                        label: submissionStatusLabel(
                          context.l10n,
                          row['status'] as String,
                        ),
                      ),
                      const SizedBox(height: 12),
                      VenueSubmissionDetails(
                        submission: row,
                        sports: widget.controller.sports,
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

class PublicVenueSubmissionScreen extends StatefulWidget {
  const PublicVenueSubmissionScreen({
    super.key,
    required this.api,
    required this.sports,
  });
  final SportVenueApiClient api;
  final List<Sport> sports;

  @override
  State<PublicVenueSubmissionScreen> createState() =>
      _PublicVenueSubmissionScreenState();
}

class _PublicVenueSubmissionScreenState
    extends State<PublicVenueSubmissionScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final Set<String> _sports = {};
  maplibre.Geographic? _point;
  String? _surface;
  bool _lighting = false;
  bool _publicConfirmed = false;
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _location() async {
    if (_saving) return;
    final point = await Navigator.of(context).push<maplibre.Geographic>(
      MaterialPageRoute(builder: (_) => LocationPicker(initialPoint: _point)),
    );
    if (mounted && point != null) setState(() => _point = point);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    final valid = _form.currentState!.validate();
    if (!valid ||
        _sports.isEmpty ||
        _sports.length > 6 ||
        _point == null ||
        !_publicConfirmed) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.api.submitPublicVenue({
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'city_id': 'moscow',
        'geo_lat': _point!.lat,
        'geo_lng': _point!.lon,
        'sport_ids': _sports.toList(),
        'surface': _surface,
        'has_lighting': _lighting,
        'description': _description.text.trim(),
        'is_public': true,
      });
      if (!mounted) return;
      // Enable pop before removing the route protected against in-flight saves.
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ApiException && error.statusCode == 422
            ? context.l10n.submissionCheckData
            : context.l10n.submissionSendFailed;
      });
    }
  }

  Widget _warning(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: context.text.bodySmall?.copyWith(color: context.colors.error),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      key: const ValueKey('public-venue-form'),
      appBar: AppBar(
        title: Text(context.l10n.publicVenueTitle),
        leading: IconButton(
          tooltip: context.l10n.back,
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const BackButtonIcon(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.publicVenueFormIntro,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('public-venue-name'),
                controller: _name,
                enabled: !_saving,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.l10n.venueNameLabel,
                  counterText: '',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? context.l10n.enterVenueName
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('public-venue-address'),
                controller: _address,
                enabled: !_saving,
                maxLength: 240,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.l10n.clubAddressLabel,
                  hintText: context.l10n.clubAddressHint,
                  counterText: '',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? context.l10n.enterAddress
                    : null,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                key: const ValueKey('public-venue-location'),
                label: _point == null
                    ? context.l10n.pickOnMap
                    : context.l10n.changeMapPoint,
                tone: ButtonTone.neutral,
                icon: Icons.location_on_outlined,
                onPressed: _saving ? null : _location,
              ),
              if (_point != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_point!.lat.toStringAsFixed(6)}, ${_point!.lon.toStringAsFixed(6)}',
                    style: AppTheme.numeric(
                      context.text.bodySmall,
                    ).copyWith(color: context.colors.muted),
                  ),
                ),
              if (_submitted && _point == null)
                _warning(context.l10n.markVenueOnMap),
              const SizedBox(height: 20),
              Text(context.l10n.sportsUpToSix, style: context.text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sport in widget.sports)
                    // The app's own chip, as everywhere a sport is picked.
                    SelectableChip(
                      label: sport.name.capitalized,
                      selected: _sports.contains(sport.id),
                      onTap: _saving
                          ? null
                          : () => setState(() {
                              if (!_sports.remove(sport.id) &&
                                  _sports.length < 6) {
                                _sports.add(sport.id);
                              }
                            }),
                    ),
                ],
              ),
              if (_submitted && _sports.isEmpty)
                _warning(context.l10n.venueSportsMissing),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: const ValueKey('public-venue-surface'),
                initialValue: _surface,
                decoration: InputDecoration(
                  labelText: context.l10n.surfaceLabel,
                ),
                items: [
                  for (final key in surfaceKeys)
                    DropdownMenuItem(
                      value: key,
                      child: Text(surfaceLabel(context.l10n, key)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _surface = value),
                validator: (value) =>
                    value == null ? context.l10n.pickSurface : null,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: context.colors.accent,
                activeTrackColor: context.colors.accent.withValues(alpha: 0.28),
                title: Text(
                  context.l10n.hasLighting,
                  style: context.text.bodyMedium,
                ),
                value: _lighting,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _lighting = value),
              ),
              TextFormField(
                key: const ValueKey('public-venue-description'),
                controller: _description,
                enabled: !_saving,
                maxLength: 5000,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: context.l10n.publicVenueAbout,
                  counterText: '',
                ),
              ),
              CheckboxListTile(
                key: const ValueKey('public-venue-confirm'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  context.l10n.publicVenueConfirm,
                  style: context.text.bodyMedium,
                ),
                value: _publicConfirmed,
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _publicConfirmed = value == true),
              ),
              if (_submitted && !_publicConfirmed)
                _warning(context.l10n.publicVenueConfirmMissing),
              if (_error != null) _warning(_error!),
              const SizedBox(height: 20),
              PrimaryButton(
                key: const ValueKey('submit-public-venue'),
                label: context.l10n.sendToModeration,
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
