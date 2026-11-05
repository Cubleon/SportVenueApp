import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../data/api_client.dart';
import '../data/app_controller.dart';
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
      if (api == null) throw StateError('Server connection required');
      final rows = await api.listVenueSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить заявки. Попробуйте ещё раз.';
      });
    }
  }

  Future<void> _add() async {
    final api = widget.controller.apiClient;
    if (api == null) {
      showAppSnack(
        context,
        'Для отправки заявки требуется подключение к серверу.',
      );
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
    showAppSnack(
      context,
      'Заявка отправлена на модерацию. После одобрения площадка появится на карте.',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('venue-submissions-screen'),
    appBar: AppBar(
      title: const Text('Мои заявки на площадки'),
      actions: [
        IconButton(
          tooltip: 'Обновить',
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
            label: 'Добавить общественную площадку',
            icon: Icons.add_location_alt_outlined,
            onPressed: _add,
          ),
          const SizedBox(height: 16),
          const Text(
            'Предложите бесплатную площадку во дворе, парке или другом общественном месте. Модератор проверит данные перед публикацией.',
          ),
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: context.colors.error)),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
          if (!_loading && _error == null && _submissions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('Вы пока не отправляли заявки.'),
            ),
          if (!_loading && _error == null)
            for (final row in _submissions)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submissionStatusLabels[row['status']] ??
                            row['status'] as String,
                        style: context.text.titleSmall?.copyWith(
                          color: context.colors.accent,
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
            ? 'Проверьте данные площадки и выбранные виды спорта.'
            : 'Не удалось отправить заявку. Данные сохранены в форме, попробуйте ещё раз.';
      });
    }
  }

  Widget _warning(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(text, style: TextStyle(color: context.colors.error)),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      key: const ValueKey('public-venue-form'),
      appBar: AppBar(
        title: const Text('Общественная площадка'),
        leading: IconButton(
          tooltip: 'Назад',
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
              const Text(
                'Добавьте бесплатную общественную площадку в Москве. Заявка появится на карте после проверки модератором.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('public-venue-name'),
                controller: _name,
                enabled: !_saving,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название площадки',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Введите название (минимум 2 символа)'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('public-venue-address'),
                controller: _address,
                enabled: !_saving,
                maxLength: 240,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Адрес',
                  hintText: 'Москва, улица и номер дома',
                ),
                validator: (value) =>
                    (value?.trim().length ?? 0) < 3 ? 'Введите адрес' : null,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                key: const ValueKey('public-venue-location'),
                label: _point == null
                    ? 'Указать на карте'
                    : 'Изменить точку на карте',
                tone: ButtonTone.neutral,
                icon: Icons.location_on_outlined,
                onPressed: _saving ? null : _location,
              ),
              if (_point != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_point!.lat.toStringAsFixed(6)}, ${_point!.lon.toStringAsFixed(6)}',
                  ),
                ),
              if (_submitted && _point == null)
                _warning('Отметьте площадку на карте.'),
              const SizedBox(height: 20),
              Text('Виды спорта (до 6)', style: context.text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sport in widget.sports)
                    FilterChip(
                      label: Text(sport.name),
                      selected: _sports.contains(sport.id),
                      onSelected: _saving
                          ? null
                          : (selected) => setState(() {
                              if (selected && _sports.length < 6) {
                                _sports.add(sport.id);
                              }
                              if (!selected) _sports.remove(sport.id);
                            }),
                    ),
                ],
              ),
              if (_submitted && _sports.isEmpty)
                _warning('Выберите хотя бы один вид спорта.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: const ValueKey('public-venue-surface'),
                initialValue: _surface,
                decoration: const InputDecoration(labelText: 'Покрытие'),
                items: surfaceLabels.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _surface = value),
                validator: (value) =>
                    value == null ? 'Выберите покрытие' : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Есть освещение'),
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
                decoration: const InputDecoration(
                  labelText: 'Описание и как пройти (необязательно)',
                ),
              ),
              CheckboxListTile(
                key: const ValueKey('public-venue-confirm'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Это общественная площадка с бесплатным доступом, не принадлежащая спортивному клубу',
                ),
                value: _publicConfirmed,
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _publicConfirmed = value == true),
              ),
              if (_submitted && !_publicConfirmed)
                _warning(
                  'Подтвердите, что площадка общественная и бесплатная.',
                ),
              if (_error != null) _warning(_error!),
              const SizedBox(height: 20),
              PrimaryButton(
                key: const ValueKey('submit-public-venue'),
                label: 'Отправить на модерацию',
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
