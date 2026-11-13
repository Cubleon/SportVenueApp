import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../../l10n/l10n.dart';
import '../data/api_client.dart';
import '../data/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

/// Club accounts manage their own catalogue and published availability here.
class ClubDashboardScreen extends StatefulWidget {
  const ClubDashboardScreen({
    super.key,
    required this.api,
    required this.onLogout,
    this.accountClubName,
  });

  final SportVenueApiClient api;
  final VoidCallback onLogout;
  final String? accountClubName;

  @override
  State<ClubDashboardScreen> createState() => _ClubDashboardScreenState();
}

class _ClubDashboardScreenState extends State<ClubDashboardScreen> {
  ApiJsonList _clubs = [];
  ApiJsonList _venues = [];
  ApiJsonList _sports = [];
  String? _selectedClubId;
  bool _loading = true;
  String? _error;
  String? _operationError;
  VoidCallback? _retryOperation;
  bool _confirmingDelete = false;
  String? _deletingTarget;

  bool get _managing => _confirmingDelete || _deletingTarget != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool keepCurrentData = false}) async {
    if (_managing && !keepCurrentData) return;
    setState(() {
      _loading = !keepCurrentData;
      _error = null;
      _operationError = null;
      _retryOperation = null;
    });
    try {
      final results = await Future.wait([
        widget.api.listManagedClubs(),
        widget.api.listManagedVenues(),
        widget.api.listSports(),
      ]);
      if (!mounted) return;
      setState(() {
        _clubs = results[0];
        _venues = results[1];
        _sports = results[2];
        if (!_clubs.any((club) => club['id'] == _selectedClubId)) {
          _selectedClubId = _clubs.firstOrNull?['id'] as String?;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (keepCurrentData) {
          _operationError = _apiError(
            context.l10n,
            error,
            context.l10n.clubDeletedReloadFailed,
          );
          _retryOperation = () => _load(keepCurrentData: true);
        } else {
          _error = _apiError(context.l10n, error, context.l10n.clubLoadFailed);
        }
      });
    }
  }

  Future<void> _editClub([ApiJsonObject? club]) async {
    if (_managing) return;
    final savedId = await _showEditor<String>(
      context,
      _ClubEditor(
        api: widget.api,
        club: club,
        initialName: _clubs.isEmpty ? widget.accountClubName ?? '' : '',
      ),
    );
    if (!mounted || savedId == null) return;
    _selectedClubId = savedId;
    await _load();
  }

  Future<void> _editVenue(ApiJsonObject club, [ApiJsonObject? venue]) async {
    if (_managing) return;
    final saved = await _showEditor<bool>(
      context,
      _VenueEditor(
        api: widget.api,
        clubId: club['id'] as String,
        sports: _sports,
        venue: venue,
      ),
    );
    if (mounted && saved == true) await _load();
  }

  Future<void> _deleteManagedItem(
    ApiJsonObject item, {
    required bool isClub,
  }) async {
    if (_managing || _loading) return;
    final id = item['id'] as String;
    final name = item['name'] as String;
    setState(() {
      _confirmingDelete = true;
      _operationError = null;
      _retryOperation = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            isClub
                ? context.l10n.deleteClubQuestion(name)
                : context.l10n.deleteVenueQuestion(name),
          ),
          content: Text(
            isClub ? context.l10n.deleteClubBody : context.l10n.deleteVenueBody,
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancel-delete-managed'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              key: const ValueKey('confirm-delete-managed'),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.deleteAction),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() {
        _confirmingDelete = false;
        _deletingTarget = '${isClub ? 'club' : 'venue'}:$id';
      });
      if (isClub) {
        await widget.api.deleteManagedClub(id);
      } else {
        await widget.api.deleteManagedVenue(id);
      }
      if (!mounted) return;
      // A confirmed server deletion remains reflected even if reloading fails.
      setState(() {
        if (isClub) {
          _clubs.removeWhere((club) => club['id'] == id);
          _venues.removeWhere((venue) => venue['club_id'] == id);
          if (_selectedClubId == id) {
            _selectedClubId = _clubs.firstOrNull?['id'] as String?;
          }
        } else {
          _venues.removeWhere((venue) => venue['id'] == id);
        }
      });
      await _load(keepCurrentData: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final l10n = context.l10n;
        _operationError = error is ApiException && error.statusCode == 409
            ? (isClub ? l10n.clubDeleteBlocked : l10n.venueDeleteBlocked)
            : _apiError(
                l10n,
                error,
                isClub ? l10n.clubDeleteFailed : l10n.venueDeleteFailed,
              );
        _retryOperation = () => _deleteManagedItem(item, isClub: isClub);
      });
    } finally {
      if (mounted) {
        setState(() {
          _confirmingDelete = false;
          _deletingTarget = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = _clubs
        .where((item) => item['id'] == _selectedClubId)
        .firstOrNull;
    final venues = _venues
        .where((item) => item['club_id'] == _selectedClubId)
        .toList();
    return Scaffold(
      key: const ValueKey('club-dashboard'),
      appBar: AppBar(
        title: Text(context.l10n.clubDashboardTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: _loading || _managing ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            key: const ValueKey('club-logout'),
            tooltip: context.l10n.logout,
            onPressed: _managing ? null : widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _LoadError(message: _error!, retry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    context.l10n.clubOnMapTitle,
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.clubOnMapBody,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_deletingTarget != null) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  if (_operationError != null) ...[
                    AppCard(
                      key: const ValueKey('club-management-error'),
                      borderColor: context.colors.error,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _operationError!,
                              style: context.text.bodyMedium?.copyWith(
                                color: context.colors.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            key: const ValueKey('retry-managed-operation'),
                            onPressed: _managing ? null : _retryOperation,
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_clubs.isEmpty)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            size: 36,
                            color: context.colors.accent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.clubStartTitle,
                            style: context.text.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.clubStartBody,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.muted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            key: const ValueKey('create-first-club'),
                            label: context.l10n.addClub,
                            icon: Icons.add_rounded,
                            onPressed: _managing ? null : _editClub,
                          ),
                        ],
                      ),
                    ),
                  if (_clubs.isNotEmpty) ...[
                    if (_clubs.length > 1) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey('select-managed-club-$_selectedClubId'),
                        initialValue: _selectedClubId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.clubPicker,
                        ),
                        items: _clubs
                            .map(
                              (item) => DropdownMenuItem(
                                value: item['id'] as String,
                                child: Text(item['name'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: _managing
                            ? null
                            : (id) => setState(() => _selectedClubId = id),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (club != null) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CardHeading(
                              title: club['name'] as String,
                              onEdit: _managing ? null : () => _editClub(club),
                              tooltip: context.l10n.editClub,
                              deleteKey: ValueKey(
                                'delete-managed-club-${club['id']}',
                              ),
                              deleteTooltip: context.l10n.deleteClub,
                              deleting: _deletingTarget == 'club:${club['id']}',
                              onDelete: _managing
                                  ? null
                                  : () =>
                                        _deleteManagedItem(club, isClub: true),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: context.colors.muted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(club['address'] as String),
                                ),
                              ],
                            ),
                            if ((club['description'] as String? ?? '')
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  club['description'] as String,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: context.colors.muted,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              venues.isEmpty
                                  ? context.l10n.clubNeedsVenue
                                  : context.l10n.clubVisible,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        context.l10n.clubVenuesTitle,
                        style: context.text.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.clubVenuesBody,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final venue in venues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            key: ValueKey('managed-venue-${venue['id']}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CardHeading(
                                  title: venue['name'] as String,
                                  onEdit: _managing
                                      ? null
                                      : () => _editVenue(club, venue),
                                  tooltip: context.l10n.editVenue,
                                  deleteKey: ValueKey(
                                    'delete-managed-venue-${venue['id']}',
                                  ),
                                  deleteTooltip: context.l10n.deleteVenue,
                                  deleting:
                                      _deletingTarget == 'venue:${venue['id']}',
                                  onDelete: _managing
                                      ? null
                                      : () => _deleteManagedItem(
                                          venue,
                                          isClub: false,
                                        ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _sports
                                      .where(
                                        (sport) => (venue['sport_ids'] as List)
                                            .contains(sport['id']),
                                      )
                                      .map((sport) => sport['name'])
                                      .join(' · '),
                                  style: context.text.bodyMedium?.copyWith(
                                    color: context.colors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // The same price as everywhere else in the
                                // app: «2 500 ₽/час», not «2500 ₽ / час».
                                Text(
                                  context.l10n.venuePriceCapacity(
                                    AppFormatters.money(
                                      venue['base_price_per_hour'] as int,
                                    ),
                                    venue['capacity_max'] as int,
                                  ),
                                  style: AppTheme.numeric(
                                    context.text.bodyMedium,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                PrimaryButton(
                                  label: context.l10n.venueSchedule,
                                  icon: Icons.calendar_month_outlined,
                                  tone: ButtonTone.neutral,
                                  onPressed: _managing
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => _AvailabilityScreen(
                                              api: widget.api,
                                              venue: venue,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      PrimaryButton(
                        key: const ValueKey('create-managed-venue'),
                        label: context.l10n.addVenue,
                        icon: Icons.add_rounded,
                        onPressed: _managing ? null : () => _editVenue(club),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _managing ? null : _editClub,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: Text(context.l10n.addAnotherClub),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ClubEditor extends StatefulWidget {
  const _ClubEditor({required this.api, this.club, this.initialName = ''});

  final SportVenueApiClient api;
  final ApiJsonObject? club;
  final String initialName;

  @override
  State<_ClubEditor> createState() => _ClubEditorState();
}

class _ClubEditorState extends State<_ClubEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.club?['name'] as String? ?? widget.initialName,
  );
  late final _address = TextEditingController(
    text: widget.club?['address'] as String?,
  );
  late final _description = TextEditingController(
    text: widget.club?['description'] as String?,
  );
  late maplibre.Geographic? _point = widget.club == null
      ? null
      : maplibre.Geographic(
          lon: (widget.club!['geo_lng'] as num).toDouble(),
          lat: (widget.club!['geo_lat'] as num).toDouble(),
        );
  bool _saving = false;
  bool _locationMissing = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    setState(() => _locationMissing = _point == null);
    if (!valid || _point == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = <String, Object?>{
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'description': _description.text.trim(),
        'geo_lat': _point!.lat,
        'geo_lng': _point!.lon,
        'city_id': widget.club?['city_id'] ?? 'moscow',
      };
      final club = widget.club == null
          ? await widget.api.createManagedClub(data: data)
          : await widget.api.updateManagedClub(
              widget.club!['id'] as String,
              data: data,
            );
      if (mounted) Navigator.pop(context, club['id'] as String);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _apiError(context.l10n, error, context.l10n.clubSaveFailed);
      });
    }
  }

  Future<void> _selectLocation() async {
    final point = await Navigator.of(context).push<maplibre.Geographic>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LocationPicker(initialPoint: _point),
      ),
    );
    if (!mounted || point == null) return;
    setState(() {
      _point = point;
      _locationMissing = false;
    });
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
    title: widget.club == null ? context.l10n.newClub : context.l10n.editClub,
    saving: _saving,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('club-name-field'),
            controller: _name,
            enabled: !_saving,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.clubNameLabel,
              counterText: '',
            ),
            validator: (value) => _required(context.l10n, value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('club-address-field'),
            controller: _address,
            enabled: !_saving,
            maxLength: 240,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.clubAddressLabel,
              hintText: context.l10n.clubAddressHint,
              counterText: '',
            ),
            validator: (value) => _required(context.l10n, value, minLength: 3),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            key: const ValueKey('club-select-location'),
            label: _point == null
                ? context.l10n.pickOnMap
                : context.l10n.changeMapPoint,
            icon: Icons.location_on_outlined,
            tone: ButtonTone.neutral,
            onPressed: _saving ? null : _selectLocation,
          ),
          const SizedBox(height: 8),
          Text(
            _locationMissing
                ? context.l10n.clubLocationMissing
                : _point == null
                ? context.l10n.clubLocationHint
                : '${_point!.lat.toStringAsFixed(6)}, ${_point!.lon.toStringAsFixed(6)}',
            style: context.text.bodySmall?.copyWith(
              color: _locationMissing
                  ? context.colors.error
                  : context.colors.muted,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            maxLength: 5000,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.clubAboutLabel,
              counterText: '',
            ),
          ),
          if (_error != null) _InlineError(message: _error!),
          const SizedBox(height: 16),
          PrimaryButton(
            key: const ValueKey('save-managed-club'),
            label: context.l10n.saveClub,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    ),
  );
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({this.initialPoint});

  final maplibre.Geographic? initialPoint;

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  late maplibre.Geographic? _point = widget.initialPoint;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.clubLocationTitle)),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            context.l10n.clubLocationBody,
            style: context.text.bodyMedium,
          ),
        ),
        Expanded(
          child: maplibre.MapLibreMap(
            key: const ValueKey('club-location-map'),
            options: maplibre.MapOptions(
              initStyle: 'https://tiles.openfreemap.org/styles/liberty',
              initCenter:
                  _point ??
                  const maplibre.Geographic(lon: 37.6173, lat: 55.7558),
              initZoom: _point == null ? 10.6 : 15,
              minZoom: 1,
              maxZoom: 19,
            ),
            onEvent: (event) {
              if (event is maplibre.MapEventClick) {
                setState(() => _point = event.point);
              }
            },
            children: [
              maplibre.WidgetLayer(
                markers: [
                  if (_point != null)
                    maplibre.Marker(
                      point: _point!,
                      size: const Size.square(44),
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: context.colors.accent,
                        semanticLabel: context.l10n.clubLocationTitle,
                      ),
                    ),
                ],
              ),
              const maplibre.MapCompass(
                alignment: Alignment.topRight,
                padding: EdgeInsets.all(12),
              ),
              const maplibre.SourceAttribution(
                alignment: Alignment.bottomLeft,
                showMapLibre: false,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PrimaryButton(
              label: context.l10n.confirmLocation,
              onPressed: _point == null
                  ? null
                  : () => Navigator.pop(context, _point),
            ),
          ),
        ),
      ],
    ),
  );
}

class _VenueEditor extends StatefulWidget {
  const _VenueEditor({
    required this.api,
    required this.clubId,
    required this.sports,
    this.venue,
  });

  final SportVenueApiClient api;
  final String clubId;
  final ApiJsonList sports;
  final ApiJsonObject? venue;

  @override
  State<_VenueEditor> createState() => _VenueEditorState();
}

class _VenueEditorState extends State<_VenueEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.venue?['name'] as String?,
  );
  late final _description = TextEditingController(
    text: widget.venue?['description'] as String?,
  );
  late final _price = TextEditingController(
    text: widget.venue?['base_price_per_hour']?.toString(),
  );
  late final _min = TextEditingController(
    text: widget.venue?['capacity_min']?.toString() ?? '1',
  );
  late final _max = TextEditingController(
    text: widget.venue?['capacity_max']?.toString(),
  );
  late final _sportIds = Set<String>.from(
    widget.venue?['sport_ids'] as List? ?? [],
  );
  bool _saving = false;
  bool _sportsMissing = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _description, _price, _min, _max]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    setState(() => _sportsMissing = _sportIds.isEmpty);
    if (!valid || _sportIds.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = <String, Object?>{
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'sport_ids': _sportIds.toList(),
        'base_price_per_hour': int.parse(_price.text.trim()),
        'capacity_min': int.parse(_min.text.trim()),
        'capacity_max': int.parse(_max.text.trim()),
      };
      if (widget.venue == null) {
        await widget.api.createManagedVenue(widget.clubId, data: data);
      } else {
        await widget.api.updateManagedVenue(
          widget.venue!['id'] as String,
          data: data,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _apiError(context.l10n, error, context.l10n.venueSaveFailed);
      });
    }
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
    title: widget.venue == null
        ? context.l10n.newVenue
        : context.l10n.editVenue,
    saving: _saving,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('managed-venue-name'),
            controller: _name,
            enabled: !_saving,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.venueNameLabel,
              hintText: context.l10n.venueNameHint,
              counterText: '',
            ),
            validator: (value) => _required(context.l10n, value),
          ),
          const SizedBox(height: 12),
          Text(context.l10n.venueSports, style: context.text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.sports.map((sport) {
              final id = sport['id'] as String;
              // The app's own chip, as on every other screen that picks
              // a sport.
              return SelectableChip(
                label: (sport['name'] as String).capitalized,
                selected: _sportIds.contains(id),
                onTap: _saving
                    ? null
                    : () => setState(() {
                        if (!_sportIds.remove(id)) {
                          _sportIds.add(id);
                        }
                        _sportsMissing = _sportIds.isEmpty;
                      }),
              );
            }).toList(),
          ),
          if (_sportsMissing)
            _InlineError(message: context.l10n.venueSportsMissing),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('managed-venue-price'),
            controller: _price,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.filterPrice,
              suffixText: '₽',
            ),
            validator: (value) =>
                _positiveInteger(context.l10n, value, max: 1000000),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _min,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.playersFrom,
                  ),
                  validator: (value) =>
                      _positiveInteger(context.l10n, value, max: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('managed-venue-capacity'),
                  controller: _max,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.playersTo,
                  ),
                  validator: (value) {
                    final error = _positiveInteger(
                      context.l10n,
                      value,
                      max: 30,
                    );
                    if (error != null) return error;
                    if (int.parse(value!.trim()) <
                        (int.tryParse(_min.text.trim()) ?? 1)) {
                      return context.l10n.lessThanMin;
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            maxLength: 5000,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.venueAboutLabel,
              hintText: context.l10n.venueAboutHint,
              counterText: '',
            ),
          ),
          if (_error != null) _InlineError(message: _error!),
          const SizedBox(height: 16),
          PrimaryButton(
            key: const ValueKey('save-managed-venue'),
            label: context.l10n.saveVenue,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    ),
  );
}

class _AvailabilityScreen extends StatefulWidget {
  const _AvailabilityScreen({required this.api, required this.venue});

  final SportVenueApiClient api;
  final ApiJsonObject venue;

  @override
  State<_AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<_AvailabilityScreen> {
  ApiJsonList _windows = [];
  bool _loading = true;
  String? _deletingId;
  String? _error;

  String get _venueId => widget.venue['id'] as String;

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
      final windows = await widget.api.listManagedAvailability(_venueId);
      windows.sort(
        (a, b) =>
            (a['starts_at'] as String).compareTo(b['starts_at'] as String),
      );
      if (!mounted) return;
      setState(() {
        _windows = windows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _apiError(
          context.l10n,
          error,
          context.l10n.scheduleLoadFailed,
        );
      });
    }
  }

  Future<void> _publish() async {
    final published = await _showEditor<bool>(
      context,
      _AvailabilityEditor(api: widget.api, venueId: _venueId),
    );
    if (mounted && published == true) await _load();
  }

  Future<void> _delete(ApiJsonObject window) async {
    if (_deletingId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unpublishQuestion),
        content: Text(context.l10n.unpublishBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.keepPublished),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.unpublish),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final id = window['id'] as String;
    setState(() => _deletingId = id);
    try {
      await widget.api.deleteManagedAvailability(_venueId, id);
      if (!mounted) return;
      setState(() => _windows.removeWhere((item) => item['id'] == id));
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException && error.statusCode == 409
          ? context.l10n.unpublishBlocked
          : _apiError(context.l10n, error, context.l10n.unpublishFailed);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.venueScheduleTitle),
      actions: [
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: _loading || _deletingId != null ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: PrimaryButton(
          key: const ValueKey('publish-availability'),
          label: context.l10n.publishFreeTime,
          icon: Icons.add_rounded,
          onPressed: _loading || _deletingId != null ? null : _publish,
        ),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _LoadError(message: _error!, retry: _load)
        : RefreshIndicator(
            onRefresh: _deletingId == null ? _load : () async {},
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  widget.venue['name'] as String,
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.scheduleBody,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.moscowTime,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                if (_windows.isEmpty)
                  AppCard(
                    child: Text(
                      context.l10n.scheduleEmpty,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                for (final window in _windows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      key: ValueKey('availability-${window['id']}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dateLabel(_moscowTime(window['starts_at'])),
                                  style: context.text.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_timeLabel(_moscowTime(window['starts_at']))}–${_windowEndLabel(window)}',
                                  style: AppTheme.numeric(
                                    context.text.titleLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_deletingId == window['id'])
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              tooltip: context.l10n.unpublish,
                              onPressed: _deletingId != null
                                  ? null
                                  : () => _delete(window),
                              color: context.colors.muted,
                              icon: const Icon(Icons.delete_outline_rounded),
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

class _AvailabilityEditor extends StatefulWidget {
  const _AvailabilityEditor({required this.api, required this.venueId});

  final SportVenueApiClient api;
  final String venueId;

  @override
  State<_AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<_AvailabilityEditor> {
  late DateTime _date = _moscowNow().add(const Duration(days: 1));
  int _startMinutes = 9 * 60;
  int _endMinutes = 22 * 60;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    if (_endMinutes <= _startMinutes) {
      setState(() => _error = context.l10n.endBeforeStart);
      return;
    }
    if (_endMinutes - _startMinutes < 60) {
      setState(() => _error = context.l10n.windowTooShort);
      return;
    }
    // Moscow has a fixed UTC+3 offset. Never use the device's timezone here.
    final midnight = DateTime.utc(_date.year, _date.month, _date.day);
    final startsAt = midnight.add(Duration(minutes: _startMinutes - 180));
    final endsAt = midnight.add(Duration(minutes: _endMinutes - 180));
    if (!startsAt.isAfter(DateTime.now().toUtc())) {
      setState(() => _error = context.l10n.pickFutureTime);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.publishManagedAvailability(
        widget.venueId,
        startsAt: startsAt,
        endsAt: endsAt,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ApiException && error.statusCode == 409
            ? context.l10n.windowOverlaps
            : _apiError(context.l10n, error, context.l10n.publishFailed);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = _moscowNow();
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (mounted && date != null) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
    title: context.l10n.freeTimeTitle,
    saving: _saving,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.freeTimeBody,
          style: context.text.bodyMedium?.copyWith(color: context.colors.muted),
        ),
        const SizedBox(height: 20),
        // The app's neutral button, not Material's thin outline.
        PrimaryButton(
          key: const ValueKey('availability-date'),
          label: _dateLabel(_date),
          icon: Icons.calendar_month_outlined,
          tone: ButtonTone.neutral,
          onPressed: _saving ? null : _pickDate,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TimeDropdown(
                key: const ValueKey('availability-start'),
                label: context.l10n.windowStart,
                value: _startMinutes,
                allowMidnightEnd: false,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _startMinutes = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeDropdown(
                key: const ValueKey('availability-end'),
                label: context.l10n.windowEnd,
                value: _endMinutes,
                allowMidnightEnd: true,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _endMinutes = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.freeTimeNote,
          style: context.text.bodySmall?.copyWith(color: context.colors.muted),
        ),
        if (_error != null) _InlineError(message: _error!),
        const SizedBox(height: 24),
        PrimaryButton(
          key: const ValueKey('save-availability'),
          label: context.l10n.publish,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    ),
  );
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.allowMidnightEnd,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool allowMidnightEnd;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: [
      for (
        var minute = allowMidnightEnd ? 30 : 0;
        minute <= (allowMidnightEnd ? 1440 : 1410);
        minute += 30
      )
        DropdownMenuItem(
          value: minute,
          child: Text(
            '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
          ),
        ),
    ],
    onChanged: onChanged == null ? null : (value) => onChanged!(value!),
  );
}

class _EditorFrame extends StatelessWidget {
  const _EditorFrame({
    required this.title,
    required this.child,
    required this.saving,
  });

  final String title;
  final Widget child;
  final bool saving;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.titleLarge)),
                IconButton(
                  tooltip: context.l10n.close,
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.title,
    required this.onEdit,
    required this.tooltip,
    required this.deleteKey,
    required this.deleteTooltip,
    required this.onDelete,
    this.deleting = false,
  });

  final String title;
  final VoidCallback? onEdit;
  final String tooltip;
  final Key deleteKey;
  final String deleteTooltip;
  final VoidCallback? onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: context.text.titleLarge)),
      IconButton(
        tooltip: tooltip,
        onPressed: onEdit,
        color: context.colors.muted,
        icon: const Icon(Icons.edit_outlined),
      ),
      if (deleting)
        SizedBox.square(
          key: deleteKey,
          dimension: 48,
          child: Semantics(
            liveRegion: true,
            label: context.l10n.deleting,
            child: const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        )
      else
        IconButton(
          key: deleteKey,
          tooltip: deleteTooltip,
          onPressed: onDelete,
          // Grey like its neighbour: red on every card shouted. The
          // dialog that follows is where the danger is spelled out.
          color: context.colors.muted,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: RetryNotice(message: message, onRetry: retry),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: context.text.bodyMedium?.copyWith(color: context.colors.error),
      ),
    ),
  );
}

Future<T?> _showEditor<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: 680),
      // The page ground, as the app's other sheets: fields are filled with
      // the card colour, and on a card-coloured sheet they disappeared.
      backgroundColor: context.colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => child,
    );

String? _required(L l10n, String? value, {int minLength = 2}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return l10n.fieldRequired;
  if (text.length < minLength) return l10n.fieldMinLength(minLength);
  return null;
}

String? _positiveInteger(L l10n, String? value, {required int max}) {
  final number = int.tryParse(value?.trim() ?? '');
  if (number == null || number < 1) return l10n.wholeNumberFromOne;
  if (number > max) return l10n.notMoreThan(max);
  return null;
}

String _apiError(L l10n, Object error, String fallback) {
  if (error is ApiException) {
    if (error.isUnauthorized) {
      return l10n.sessionEnded;
    }
    if (error.statusCode == 403) return l10n.noClubAccess;
    if (error.kind == ApiExceptionKind.network) {
      return '$fallback ${l10n.checkConnection}';
    }
    if (error.statusCode == 422) {
      return l10n.checkFields;
    }
  }
  return fallback;
}

DateTime _moscowNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

DateTime _moscowTime(dynamic iso) =>
    DateTime.parse(iso as String).toUtc().add(const Duration(hours: 3));

/// «пятница, 14 ноября», as the rest of the app writes a day.
String _dateLabel(DateTime date) =>
    AppFormatters.dateFull(date, now: _moscowNow()).capitalized;

String _timeLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _windowEndLabel(ApiJsonObject window) {
  final start = _moscowTime(window['starts_at']);
  final end = _moscowTime(window['ends_at']);
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return _timeLabel(end);
  }
  return '${_timeLabel(end)} (${AppFormatters.dateShort(end)})';
}
