import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../data/api_client.dart';
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
            error,
            'Удаление выполнено, но обновить кабинет не удалось.',
          );
          _retryOperation = () => _load(keepCurrentData: true);
        } else {
          _error = _apiError(error, 'Не удалось загрузить кабинет клуба.');
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
            isClub ? 'Удалить клуб «$name»?' : 'Удалить площадку «$name»?',
          ),
          content: Text(
            isClub
                ? 'Клуб и все его площадки исчезнут с карты. Опубликованное расписание будет скрыто. История бронирований сохранится. Аккаунт клуба останется.'
                : 'Площадка и её расписание больше не будут доступны для новых бронирований. История бронирований сохранится.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancel-delete-managed'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              key: const ValueKey('confirm-delete-managed'),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
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
        final noun = isClub ? 'клуб' : 'площадку';
        _operationError = error is ApiException && error.statusCode == 409
            ? 'Нельзя удалить $noun: есть предстоящие бронирования, игры или временные блокировки. Дождитесь их завершения.'
            : _apiError(error, 'Не удалось удалить $noun. Попробуйте ещё раз.');
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
        title: const Text('Кабинет клуба'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading || _managing ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            key: const ValueKey('club-logout'),
            tooltip: 'Выйти из аккаунта',
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
                  Text('Ваш клуб на карте', style: context.text.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                    'Добавьте клуб и его площадки, затем опубликуйте свободное время. Игроки увидят их на карте и смогут бронировать.',
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
                            child: const Text('Повторить'),
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
                            'Начнём с адреса',
                            style: context.text.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Укажите название, адрес и отметьте клуб на карте.',
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            key: const ValueKey('create-first-club'),
                            label: 'Добавить клуб',
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
                        decoration: const InputDecoration(labelText: 'Клуб'),
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
                              tooltip: 'Редактировать клуб',
                              deleteKey: ValueKey(
                                'delete-managed-club-${club['id']}',
                              ),
                              deleteTooltip: 'Удалить клуб',
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
                                  size: 20,
                                  color: context.colors.accent,
                                ),
                                const SizedBox(width: 6),
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
                                  ? 'Чтобы появиться в поиске, добавьте первую площадку.'
                                  : 'Клуб доступен игрокам на карте.',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Спортивные площадки',
                        style: context.text.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Для каждого корта, зала или поля — своё расписание.',
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
                                  tooltip: 'Редактировать площадку',
                                  deleteKey: ValueKey(
                                    'delete-managed-venue-${venue['id']}',
                                  ),
                                  deleteTooltip: 'Удалить площадку',
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
                                Text(
                                  '${venue['base_price_per_hour']} ₽ / час · до ${venue['capacity_max']} игроков',
                                  style: context.text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                PrimaryButton(
                                  label: 'Расписание и свободное время',
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
                        label: 'Добавить площадку',
                        icon: Icons.add_rounded,
                        onPressed: _managing ? null : () => _editVenue(club),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _managing ? null : _editClub,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Добавить ещё один клуб'),
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
        _error = _apiError(
          error,
          'Не удалось сохранить клуб. Попробуйте ещё раз.',
        );
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
    title: widget.club == null ? 'Новый клуб' : 'Редактировать клуб',
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
            decoration: const InputDecoration(labelText: 'Название клуба'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('club-address-field'),
            controller: _address,
            enabled: !_saving,
            maxLength: 240,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Адрес',
              hintText: 'Москва, улица и номер дома',
            ),
            validator: (value) => _required(value, minLength: 3),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            key: const ValueKey('club-select-location'),
            label: _point == null
                ? 'Указать на карте'
                : 'Изменить точку на карте',
            icon: Icons.location_on_outlined,
            tone: ButtonTone.neutral,
            onPressed: _saving ? null : _selectLocation,
          ),
          const SizedBox(height: 8),
          Text(
            _locationMissing
                ? 'Отметьте расположение клуба на карте.'
                : _point == null
                ? 'Игроки увидят клуб в этой точке.'
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
            decoration: const InputDecoration(
              labelText: 'О клубе (необязательно)',
            ),
          ),
          if (_error != null) _InlineError(message: _error!),
          const SizedBox(height: 16),
          PrimaryButton(
            key: const ValueKey('save-managed-club'),
            label: 'Сохранить клуб',
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
    appBar: AppBar(title: const Text('Расположение клуба')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            'Приблизьте карту и нажмите на место, где находится вход в клуб.',
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
                        semanticLabel: 'Расположение клуба',
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
              label: 'Подтвердить расположение',
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
        _error = _apiError(
          error,
          'Не удалось сохранить площадку. Попробуйте ещё раз.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
    title: widget.venue == null ? 'Новая площадка' : 'Редактировать площадку',
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
            decoration: const InputDecoration(
              labelText: 'Название площадки',
              hintText: 'Например, теннисный корт №1',
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          Text('Виды спорта', style: context.text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.sports.map((sport) {
              final id = sport['id'] as String;
              return FilterChip(
                label: Text(sport['name'] as String),
                selected: _sportIds.contains(id),
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                        selected ? _sportIds.add(id) : _sportIds.remove(id);
                        _sportsMissing = _sportIds.isEmpty;
                      }),
              );
            }).toList(),
          ),
          if (_sportsMissing)
            const _InlineError(message: 'Выберите хотя бы один вид спорта.'),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('managed-venue-price'),
            controller: _price,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Цена за час',
              suffixText: '₽',
            ),
            validator: (value) => _positiveInteger(value, max: 1000000),
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
                  decoration: const InputDecoration(labelText: 'Игроков от'),
                  validator: (value) => _positiveInteger(value, max: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('managed-venue-capacity'),
                  controller: _max,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Игроков до'),
                  validator: (value) {
                    final error = _positiveInteger(value, max: 30);
                    if (error != null) return error;
                    if (int.parse(value!.trim()) <
                        (int.tryParse(_min.text.trim()) ?? 1)) {
                      return 'Меньше минимума';
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
            decoration: const InputDecoration(
              labelText: 'Описание (необязательно)',
              hintText: 'Покрытие, оборудование и другие особенности',
            ),
          ),
          if (_error != null) _InlineError(message: _error!),
          const SizedBox(height: 16),
          PrimaryButton(
            key: const ValueKey('save-managed-venue'),
            label: 'Сохранить площадку',
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
        _error = _apiError(error, 'Не удалось загрузить расписание.');
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
        title: const Text('Снять время с публикации?'),
        content: const Text(
          'Этот промежуток больше не будет доступен для бронирования. Если на него уже есть бронь, снять публикацию не получится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Оставить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Снять с публикации'),
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
          ? 'На это время есть бронь или временная блокировка. Снять публикацию сейчас нельзя.'
          : _apiError(
              error,
              'Не удалось снять публикацию. Попробуйте ещё раз.',
            );
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
      title: const Text('Расписание площадки'),
      actions: [
        IconButton(
          tooltip: 'Обновить',
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
          label: 'Опубликовать свободное время',
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
                  'Публикуйте только время, когда площадка свободна. Внутри этих промежутков игроки выбирают время и длительность бронирования.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Московское время (UTC+3)',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.accent,
                  ),
                ),
                const SizedBox(height: 24),
                if (_windows.isEmpty)
                  const AppCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Свободное время пока не опубликовано. Добавьте первый промежуток, чтобы открыть бронирование.',
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
                                  '${_timeLabel(_moscowTime(window['starts_at']))} — ${_windowEndLabel(window)}',
                                  style: context.text.titleLarge,
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
                              tooltip: 'Снять с публикации',
                              onPressed: _deletingId != null
                                  ? null
                                  : () => _delete(window),
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
      setState(() => _error = 'Окончание должно быть позже начала.');
      return;
    }
    if (_endMinutes - _startMinutes < 60) {
      setState(() => _error = 'Промежуток должен быть не короче 1 часа.');
      return;
    }
    // Moscow has a fixed UTC+3 offset. Never use the device's timezone here.
    final midnight = DateTime.utc(_date.year, _date.month, _date.day);
    final startsAt = midnight.add(Duration(minutes: _startMinutes - 180));
    final endsAt = midnight.add(Duration(minutes: _endMinutes - 180));
    if (!startsAt.isAfter(DateTime.now().toUtc())) {
      setState(() => _error = 'Выберите время в будущем.');
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
            ? 'Это время пересекается с уже опубликованным промежутком. Выберите другое время.'
            : _apiError(
                error,
                'Не удалось опубликовать время. Попробуйте ещё раз.',
              );
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
    title: 'Свободное время',
    saving: _saving,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Выберите дату и промежуток, доступный для бронирования.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.muted),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const ValueKey('availability-date'),
          onPressed: _saving ? null : _pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(_dateLabel(_date)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TimeDropdown(
                key: const ValueKey('availability-start'),
                label: 'Начало',
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
                label: 'Окончание',
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
          'Московское время (UTC+3). Шаг — 30 минут. Для нескольких дней добавьте отдельный промежуток на каждый день.',
          style: context.text.bodySmall?.copyWith(color: context.colors.muted),
        ),
        if (_error != null) _InlineError(message: _error!),
        const SizedBox(height: 24),
        PrimaryButton(
          key: const ValueKey('save-availability'),
          label: 'Опубликовать',
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
                  tooltip: 'Закрыть',
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
        icon: const Icon(Icons.edit_outlined),
      ),
      if (deleting)
        SizedBox.square(
          key: deleteKey,
          dimension: 48,
          child: Semantics(
            liveRegion: true,
            label: 'Удаляем',
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
          color: context.colors.error,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
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
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => child,
    );

String? _required(String? value, {int minLength = 2}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Заполните это поле';
  if (text.length < minLength) return 'Минимум $minLength символа';
  return null;
}

String? _positiveInteger(String? value, {required int max}) {
  final number = int.tryParse(value?.trim() ?? '');
  if (number == null || number < 1) return 'Введите целое число от 1';
  if (number > max) return 'Не больше $max';
  return null;
}

String _apiError(Object error, String fallback) {
  if (error is ApiException) {
    if (error.isUnauthorized) {
      return 'Сессия завершилась. Войдите в аккаунт снова.';
    }
    if (error.statusCode == 403) return 'У этого аккаунта нет доступа к клубу.';
    if (error.kind == ApiExceptionKind.network) {
      return '$fallback Проверьте подключение к интернету.';
    }
    if (error.statusCode == 422) {
      return 'Проверьте заполненные поля и попробуйте ещё раз.';
    }
  }
  return fallback;
}

DateTime _moscowNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

DateTime _moscowTime(dynamic iso) =>
    DateTime.parse(iso as String).toUtc().add(const Duration(hours: 3));

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

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
  return '${_timeLabel(end)} (${_dateLabel(end)})';
}
