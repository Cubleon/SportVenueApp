import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../data/api_client.dart';
import '../data/app_controller.dart';
import '../labels.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });
  final Future<String?> Function(String email) onContinue;
  final VoidCallback onBack;

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _email = TextEditingController();
  bool _accepted = false;
  bool _consentMissing = false;
  bool _busy = false;
  String? _error;

  bool get _valid =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim());

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_valid || _busy) return;
    if (!_accepted) {
      setState(() => _consentMissing = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onContinue(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: Text(l10n.signInWithEmail),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 52)),
              const SizedBox(height: 28),
              Text(l10n.emailSignInTitle, style: context.text.headlineSmall),
              const SizedBox(height: 12),
              Text(
                l10n.emailSignInHint,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                key: const ValueKey('email-field'),
                controller: _email,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                inputFormatters: [LengthLimitingTextInputFormatter(254)],
                decoration: InputDecoration(
                  labelText: l10n.emailLabel,
                  hintText: 'you@example.com',
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _continue(),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                key: const ValueKey('email-consent-toggle'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _accepted = value ?? false;
                        if (_accepted) _consentMissing = false;
                      }),
                title: Text(l10n.consent, style: context.text.bodySmall),
              ),
              if (_consentMissing)
                Text(
                  l10n.consentRequired,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('send-email-code'),
                label: l10n.sendEmailCode,
                onPressed: _valid && !_busy ? _continue : null,
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.challenge,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
    required this.onCancel,
    this.codeAccepted,
    this.now,
  });

  final String email;
  final ApiEmailChallenge challenge;
  final Future<void> Function(String code) onVerify;
  final Future<ApiEmailChallenge> Function() onResend;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final bool Function()? codeAccepted;
  final DateTime Function()? now;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _code = TextEditingController();
  late ApiEmailChallenge _challenge = widget.challenge;
  Timer? _timer;
  bool _busy = false;
  bool _terminal = false;
  String? _error;

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  int _remaining(DateTime date) =>
      math.max(0, (date.difference(_now).inMilliseconds / 1000).ceil());
  bool get _accepted => widget.codeAccepted?.call() ?? false;
  bool get _expired =>
      !_accepted && (_terminal || _remaining(_challenge.expiresAt) == 0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (!_terminal && !_accepted && _remaining(_challenge.expiresAt) == 0) {
          _error = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    widget.onCancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _expired || _code.text.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      await widget.onVerify(_code.text);
    } catch (error) {
      if (!mounted) return;
      final kind = AppController.kindOf(error);
      setState(() {
        _terminal =
            kind == AppErrorKind.emailChallengeExpired ||
            kind == AppErrorKind.emailAttemptsExceeded;
        _error = errorTextFor(l10n, error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _accepted || _remaining(_challenge.resendAvailableAt) > 0) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      final next = await widget.onResend();
      if (!mounted) return;
      setState(() {
        _challenge = next;
        _terminal = false;
        _code.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorTextFor(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seconds = _remaining(_challenge.expiresAt);
    final resendSeconds = _remaining(_challenge.resendAvailableAt);
    final remaining =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: widget.onBack)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.emailCodeTitle,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.emailCodeSent(widget.email),
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: 28),
              TextField(
                key: const ValueKey('email-code-field'),
                controller: _code,
                enabled: !_busy && !_expired && !_accepted,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: context.text.headlineMedium?.copyWith(letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '000000',
                  labelText: l10n.emailCodeLabel,
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 16),
              if (_expired && _error == null)
                Text(
                  l10n.errorEmailChallengeExpired,
                  key: const ValueKey('email-code-expired'),
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                )
              else if (!_expired && !_accepted)
                Text(
                  l10n.emailCodeExpiresIn(remaining),
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              const SizedBox(height: 20),
              PrimaryButton(
                key: const ValueKey('verify-email-code'),
                label: _accepted ? l10n.continueLabel : l10n.verifyEmailCode,
                onPressed: !_busy && !_expired && _code.text.length == 6
                    ? _verify
                    : null,
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    key: const ValueKey('email-code-error'),
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.emailCheckSpam,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.muted,
                ),
              ),
              TextButton(
                key: const ValueKey('resend-email-code'),
                onPressed: !_busy && !_accepted && resendSeconds == 0
                    ? _resend
                    : null,
                child: Text(
                  resendSeconds > 0
                      ? l10n.resendEmailCodeIn(resendSeconds)
                      : l10n.resendEmailCode,
                ),
              ),
              TextButton(
                onPressed: widget.onBack,
                child: Text(l10n.changeEmail),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
