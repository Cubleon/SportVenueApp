import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ClubNameSetupScreen extends StatefulWidget {
  const ClubNameSetupScreen({
    super.key,
    required this.onContinue,
    required this.onLogout,
    this.initialName = '',
  });

  final Future<String?> Function(String name) onContinue;
  final VoidCallback onLogout;
  final String initialName;

  @override
  State<ClubNameSetupScreen> createState() => _ClubNameSetupScreenState();
}

class _ClubNameSetupScreenState extends State<ClubNameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _continue() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final name = _normalize(_name.text);
    setState(() {
      _saving = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onContinue(name);
    } catch (_) {
      error = 'Не удалось сохранить название. Попробуйте ещё раз.';
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      key: const ValueKey('club-name-setup-screen'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const ValueKey('club-name-logout'),
            onPressed: _saving ? null : widget.onLogout,
            child: const Text('Выйти'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(size: 64)),
                const SizedBox(height: 32),
                Text(
                  'Как называется ваш клуб?',
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  'Укажите название клуба. Адрес, площадки и расписание добавим в личном кабинете.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const ValueKey('club-name-field'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Название клуба',
                    hintText: 'Например, Спортклуб «Арена»',
                  ),
                  validator: (value) {
                    final name = _normalize(value ?? '');
                    if (name.isEmpty) return 'Введите название клуба';
                    if (name.runes.length < 2) return 'Минимум 2 символа';
                    if (name.runes.length > 160) {
                      return 'Не больше 160 символов';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() => _error = null),
                  onFieldSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  key: const ValueKey('save-club-name'),
                  label: _saving ? 'Сохраняем…' : 'Продолжить',
                  isLoading: _saving,
                  onPressed: _continue,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
