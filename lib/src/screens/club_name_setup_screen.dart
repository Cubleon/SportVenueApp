import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    String? error;
    try {
      error = await widget.onContinue(name);
    } catch (_) {
      error = l10n.clubNameSaveFailed;
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
            child: Text(context.l10n.signOutShort),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(size: 64)),
                const SizedBox(height: 32),
                Text(
                  context.l10n.clubNameQuestion,
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.clubNameBody,
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
                  decoration: InputDecoration(
                    labelText: context.l10n.clubNameLabel,
                    hintText: context.l10n.clubNameHint,
                    counterText: '',
                  ),
                  validator: (value) {
                    final name = _normalize(value ?? '');
                    if (name.isEmpty) return context.l10n.enterClubName;
                    if (name.runes.length < 2) {
                      return context.l10n.fieldMinLength(2);
                    }
                    if (name.runes.length > 160) {
                      return context.l10n.notMoreThan(160);
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() => _error = null),
                  onFieldSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  key: const ValueKey('save-club-name'),
                  label: _saving
                      ? context.l10n.saving
                      : context.l10n.continueLabel,
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
