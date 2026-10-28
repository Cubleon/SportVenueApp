import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';

import '../data/api_client.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../labels.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Long enough to read the mark, short enough not to be a toll gate.
  /// Nothing is fetched before the first screen, so this is the entire wait,
  /// and it is owed to the brand rather than to any work.
  static const _duration = Duration(milliseconds: 1100);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  bool _left = false;

  @override
  void initState() {
    super.initState();
    // The wait ends with the animation rather than beside it. Two timers of
    // the same length drift apart the moment the device is busy, and then
    // the bar is still filling after the screen has changed under it.
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish();
        }
      })
      ..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Someone who has asked the system to stop animations is not waiting
    // through ours.
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  void _finish() {
    if (_left || !mounted) {
      return;
    }
    _left = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // A splash nobody can dismiss is a wait, however short it is. A tap
        // anywhere takes the impatient straight through.
        child: Semantics(
          button: true,
          label: context.l10n.skipSplash,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _finish,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final pulse =
                          0.35 +
                          math.sin(_controller.value * math.pi * 2) * 0.08;
                      return Center(
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                context.colors.accent.withValues(alpha: pulse),
                                context.colors.accent.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.05, 0.45),
                    ),
                    child: const AppLogo(size: 82, showWordmark: true),
                  ),
                ),
                Positioned(
                  left: 32,
                  right: 32,
                  bottom: 46,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 2,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final value = Curves.easeInOutCubic.transform(
                            _controller.value,
                          );
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor: context.colors.ink.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              context.colors.accent,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.onContinue, this.onEmail});

  final Future<String?> Function(String phone) onContinue;
  final VoidCallback? onEmail;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _controller = TextEditingController();
  bool _accepted = false;
  bool _submitting = false;
  String? _errorText;
  String _digits = '';

  /// Set when someone presses the button without having ticked the box.
  ///
  /// The button used to grey itself out instead, which answers the question
  /// "may I continue" and not the one being asked, which is "why not".
  bool _consentMissing = false;

  bool get _isValid => _digits.length == 10;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 52)),
              const SizedBox(height: 32),
              Text(
                context.l10n.signInTitle,
                // Weight and tracking come from the scale. Only the line
                // height is set here, because this is the one title in the
                // app that runs to two lines.
                style: context.text.headlineSmall?.copyWith(height: 1.12),
              ),
              const SizedBox(height: 28),
              TextField(
                key: const ValueKey('phone-field'),
                controller: _controller,
                keyboardType: TextInputType.phone,
                // The number the keyboard already knows, offered rather than
                // typed again.
                autofillHints: const [AutofillHints.telephoneNumber],
                autofocus: true,
                inputFormatters: [_RuPhoneFormatter()],
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                decoration: InputDecoration(
                  hintText: '+7 (000) 000-00-00',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _RussianFlag(),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 24,
                          color: context.colors.ink.withValues(alpha: 0.12),
                        ),
                      ],
                    ),
                  ),
                ),
                onChanged: (value) {
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  setState(() {
                    _digits = digits.startsWith('7')
                        ? digits.substring(1)
                        : digits;
                  });
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                key: const ValueKey('consent-toggle'),
                onTap: () => setState(() {
                  _accepted = !_accepted;
                  if (_accepted) _consentMissing = false;
                }),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: context.motion(
                          const Duration(milliseconds: 160),
                        ),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _accepted
                              ? context.colors.accent
                              : context.colors.surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: _accepted
                                ? context.colors.accent
                                : _consentMissing
                                ? context.colors.error
                                : context.colors.border,
                            width: _consentMissing && !_accepted ? 2 : 1.5,
                          ),
                        ),
                        // The tick sits on the accent fill, so it takes the
                        // accent's own contrast colour: near-black on blue
                        // was 2.6:1, which is a mark you have to look for.
                        child: _accepted
                            ? Icon(
                                AppIcons.check,
                                size: 16,
                                color: context.colors.onAccent,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.consent,
                          style: context.text.bodySmall?.copyWith(
                            color: _consentMissing && !_accepted
                                ? context.colors.error
                                : context.colors.muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_consentMissing && !_accepted)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: Text(
                    context.l10n.consentRequired,
                    key: const ValueKey('consent-required'),
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              PrimaryButton(
                key: const ValueKey('registration-continue'),
                label: context.l10n.continueLabel,
                onPressed: _isValid && !_submitting ? _continue : null,
              ),
              if (widget.onEmail != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const ValueKey('email-sign-in'),
                  onPressed: _submitting ? null : widget.onEmail,
                  child: Text(context.l10n.signInWithEmail),
                ),
              ],
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorText!,
                    textAlign: TextAlign.center,
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

  Future<void> _continue() async {
    if (!_accepted) {
      // Answering the press, rather than refusing it: the reason is put on
      // the row that holds the answer.
      setState(() => _consentMissing = true);
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final error = await widget.onContinue(AppFormatters.phone(_digits));
    if (!mounted || error == null) return;
    setState(() {
      _submitting = false;
      _errorText = error;
    });
  }
}

class CallVerificationScreen extends StatefulWidget {
  const CallVerificationScreen({
    super.key,
    required this.phone,
    required this.challenge,
    required this.onCheck,
    required this.onRestart,
    required this.onBack,
    required this.onCancel,
    this.openDialer,
    this.now,
  });

  final String phone;
  final ApiPhoneChallenge challenge;
  final Future<PhoneCallStatus> Function() onCheck;
  final Future<ApiPhoneChallenge> Function() onRestart;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final Future<bool> Function(Uri)? openDialer;
  final DateTime Function()? now;

  @override
  State<CallVerificationScreen> createState() => _CallVerificationScreenState();
}

class _CallVerificationScreenState extends State<CallVerificationScreen>
    with WidgetsBindingObserver {
  late ApiPhoneChallenge _challenge = widget.challenge;
  Timer? _countdown;
  Timer? _poll;
  bool _checking = false;
  bool _restarting = false;
  bool _launching = false;
  bool _background = false;
  bool _finished = false;
  bool _serverExpired = false;
  bool _dialerUnavailable = false;
  String? _error;

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  int get _seconds => math.max(
    0,
    (_challenge.expiresAt.difference(_now).inMilliseconds / 1000).ceil(),
  );
  bool get _expired => _serverExpired || _seconds == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimers();
  }

  void _startTimers() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _background || _finished) return;
      setState(() {});
      if (_expired) {
        _countdown?.cancel();
        _poll?.cancel();
      }
    });
    _scheduleCheck();
  }

  void _scheduleCheck() {
    _poll?.cancel();
    if (_expired || _finished) _countdown?.cancel();
    if (!_background && !_expired && !_finished) {
      _poll = Timer(const Duration(seconds: 3), _check);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background) {
      _poll?.cancel();
      _countdown?.cancel();
    } else {
      setState(() {});
      _startTimers();
      _check();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    _poll?.cancel();
    widget.onCancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _restarting || _expired || _finished || _background) {
      return;
    }
    _poll?.cancel();
    setState(() => _checking = true);
    final l10n = context.l10n;
    try {
      final status = await widget.onCheck();
      if (!mounted) return;
      setState(() {
        _error = null;
        _serverExpired = status == PhoneCallStatus.expired;
        _finished = status == PhoneCallStatus.confirmed;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverExpired =
            AppController.kindOf(error) == AppErrorKind.challengeExpired;
        _error = _serverExpired ? null : errorTextFor(l10n, error);
      });
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        _scheduleCheck();
      }
    }
  }

  Future<void> _restart() async {
    if (_restarting || _checking) return;
    setState(() => _restarting = true);
    final l10n = context.l10n;
    try {
      final challenge = await widget.onRestart();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _serverExpired = false;
        _error = null;
        _dialerUnavailable = false;
      });
      _startTimers();
    } catch (error) {
      if (mounted) setState(() => _error = errorTextFor(l10n, error));
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  Future<void> _call() async {
    if (_launching || _expired) return;
    setState(() => _launching = true);
    try {
      final uri = Uri(scheme: 'tel', path: _challenge.callPhone);
      final opened = await (widget.openDialer?.call(uri) ?? launchUrl(uri));
      if (mounted) setState(() => _dialerUnavailable = !opened);
    } catch (_) {
      if (mounted) setState(() => _dialerUnavailable = true);
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remaining =
        '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _IconBox(
                  icon: AppIcons.chevronLeft,
                  onTap: widget.onBack,
                ),
              ),
              const SizedBox(height: 38),
              Text(
                l10n.callToSignIn,
                textAlign: TextAlign.center,
                style: context.text.headlineMedium,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.callFromPhone(widget.phone),
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: 28),
              SelectableText(
                _challenge.callPhonePretty,
                key: const ValueKey('call-number'),
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _challenge.callPhone),
                  );
                  if (context.mounted) showAppSnack(context, l10n.phoneCopied);
                },
                child: Text(l10n.copyPhoneNumber),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.callInstructions,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: 24),
              if (!_expired) ...[
                PrimaryButton(
                  key: const ValueKey('call-phone'),
                  label: l10n.callPhone,
                  onPressed: _launching || _finished ? null : _call,
                ),
                const SizedBox(height: 18),
                Text(
                  _finished ? l10n.callConfirmed : l10n.waitingForCall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.callExpiresIn(remaining),
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
                TextButton(
                  key: const ValueKey('check-call'),
                  onPressed: _checking || _finished ? null : _check,
                  child: Text(l10n.checkCall),
                ),
              ] else ...[
                Text(
                  l10n.errorChallengeExpired,
                  key: const ValueKey('call-expired'),
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.error,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  key: const ValueKey('restart-call'),
                  label: l10n.restartCall,
                  onPressed: _checking || _restarting ? null : _restart,
                ),
              ],
              if (_checking || _restarting)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (_dialerUnavailable)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    l10n.dialerUnavailable,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onBack,
                child: Text(l10n.changePhone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('7')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    final buffer = StringBuffer('+7');
    if (digits.isNotEmpty) {
      buffer.write(' (');
      buffer.write(digits.substring(0, math.min(3, digits.length)));
    }
    if (digits.length >= 3) {
      buffer.write(')');
    }
    if (digits.length > 3) {
      buffer.write(' ${digits.substring(3, math.min(6, digits.length))}');
    }
    if (digits.length > 6) {
      buffer.write('-${digits.substring(6, math.min(8, digits.length))}');
    }
    if (digits.length > 8) {
      buffer.write('-${digits.substring(8, math.min(10, digits.length))}');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _RussianFlag extends StatelessWidget {
  const _RussianFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 22,
        height: 16,
        child: Column(
          children: const [
            Expanded(child: ColoredBox(color: Colors.white)),
            Expanded(child: ColoredBox(color: Color(0xFF0039A6))),
            Expanded(child: ColoredBox(color: Color(0xFFD52B1E))),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: context.colors.ink),
        ),
      ),
    );
  }
}
