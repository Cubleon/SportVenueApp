import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ClubLoginScreen extends StatefulWidget {
  const ClubLoginScreen({
    super.key,
    required this.onLogin,
    required this.onBack,
    this.moderator = false,
  });

  final Future<String?> Function(String login, String password) onLogin;
  final VoidCallback onBack;
  final bool moderator;

  @override
  State<ClubLoginScreen> createState() => _ClubLoginScreenState();
}

class _ClubLoginScreenState extends State<ClubLoginScreen> {
  String get _prefix => widget.moderator ? 'moderator' : 'club';
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    String? error;
    try {
      error = await widget.onLogin(_login.text.trim(), _password.text);
    } catch (_) {
      error = l10n.signInFailed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      key: ValueKey('$_prefix-login-screen'),
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.back,
          onPressed: _busy ? null : widget.onBack,
          icon: const BackButtonIcon(),
        ),
        title: Text(
          widget.moderator
              ? context.l10n.moderatorSignIn
              : context.l10n.clubSignInTitle,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 64)),
                  const SizedBox(height: 32),
                  Text(
                    widget.moderator
                        ? context.l10n.moderationTitle
                        : context.l10n.manageYourClub,
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.loginPasswordHint,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    key: ValueKey('$_prefix-login-field'),
                    controller: _login,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: context.l10n.loginLabel,
                    ),
                    validator: (value) => (value?.trim() ?? '').isEmpty
                        ? context.l10n.enterLogin
                        : null,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey('$_prefix-password-field'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: !_passwordVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: context.l10n.passwordLabel,
                      suffixIcon: IconButton(
                        key: ValueKey('$_prefix-password-visibility'),
                        tooltip: _passwordVisible
                            ? context.l10n.hidePassword
                            : context.l10n.showPassword,
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? context.l10n.enterPassword
                        : null,
                    onChanged: (_) => setState(() => _error = null),
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    key: ValueKey('$_prefix-login-submit'),
                    label: _busy ? context.l10n.signingIn : context.l10n.signIn,
                    isLoading: _busy,
                    onPressed: _signIn,
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
    ),
  );
}
