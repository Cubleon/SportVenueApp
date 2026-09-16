import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/formatters.dart';
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        widget.onFinished();
      }
    });
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
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final pulse =
                      0.35 + math.sin(_controller.value * math.pi * 2) * 0.08;
                  return Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: pulse),
                            AppColors.accent.withValues(alpha: 0.08),
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
                        backgroundColor: AppColors.white.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
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
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.onContinue});

  final Future<String?> Function(String phone) onContinue;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _controller = TextEditingController();
  bool _accepted = false;
  bool _submitting = false;
  String? _errorText;
  String _digits = '';

  bool get _isValid => _digits.length == 10 && _accepted;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 52)),
              const SizedBox(height: 32),
              Text(
                'Войти или\nзарегистрироваться',
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                key: const ValueKey('phone-field'),
                controller: _controller,
                keyboardType: TextInputType.phone,
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
                          color: AppColors.white.withValues(alpha: 0.12),
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
                onTap: () => setState(() => _accepted = !_accepted),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _accepted
                              ? AppColors.accent
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: _accepted
                                ? AppColors.accent
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: _accepted
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Согласен с обработкой персональных данных и условиями сервиса',
                          style: context.text.bodySmall?.copyWith(
                            color: AppColors.dim,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                key: const ValueKey('registration-continue'),
                label: 'Продолжить',
                onPressed: _isValid && !_submitting ? _continue : null,
              ),
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
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'или',
                      style: context.text.bodySmall?.copyWith(
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SocialButton(
                      label: 'G',
                      color: const Color(0xFF4285F4),
                      onTap: _stubSocial,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialButton(
                      label: 'VK',
                      color: AppColors.accent,
                      onTap: _stubSocial,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialButton(
                      label: '',
                      color: AppColors.white,
                      onTap: _stubSocial,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.28),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _stubSocial() {
    showAppSnack(context, 'Социальный вход подключится позже');
  }

  Future<void> _continue() async {
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

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.onVerified,
    required this.onResend,
    required this.onBack,
  });

  final String phone;
  final Future<String?> Function(String code) onVerified;
  final Future<String?> Function() onResend;
  final VoidCallback onBack;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _nodes = List.generate(4, (_) => FocusNode());
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Timer? _timer;
  int _seconds = 59;
  bool _error = false;
  bool _submitting = false;
  String _errorText = 'Неверный код, попробуйте ещё раз';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _IconBox(
                    icon: Icons.chevron_left_rounded,
                    onTap: widget.onBack,
                  ),
                  const Spacer(),
                  const AppLogo(size: 38),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                'Введите код',
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Мы звоним на ${widget.phone}. Введите последние 4 цифры входящего номера',
                style: context.text.bodyMedium?.copyWith(color: AppColors.dim),
              ),
              const SizedBox(height: 34),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final offset = math.sin(_shake.value * math.pi * 6) * 8;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: index == 3 ? 0 : 10),
                      child: SizedBox(
                        width: 66,
                        child: TextField(
                          key: ValueKey('otp-$index'),
                          controller: _controllers[index],
                          focusNode: _nodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          enabled: !_submitting,
                          style: context.text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            errorText: null,
                            filled: true,
                            fillColor: _error
                                ? AppColors.error.withValues(alpha: 0.08)
                                : AppColors.surface,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: _error
                                    ? AppColors.error
                                    : AppColors.border,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) => _onOtpChanged(index, value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _error ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _errorText,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              TextButton(
                key: const ValueKey('resend-otp'),
                onPressed: _seconds == 0 ? _resend : null,
                child: Text(
                  _seconds == 0
                      ? 'Отправить повторно'
                      : 'Отправить повторно через $_seconds с',
                ),
              ),
              const Spacer(),
              Text(
                'Не отвечайте на звонок — нужны только последние 4 цифры номера',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: AppColors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      final chars = value.characters.take(4).toList();
      for (var i = 0; i < chars.length; i++) {
        _controllers[i].text = chars[i];
      }
    }

    setState(() => _error = false);
    if (value.isNotEmpty && index < 3) {
      _nodes[index + 1].requestFocus();
    }

    final code = _controllers.map((controller) => controller.text).join();
    if (code.length == 4) {
      FocusScope.of(context).unfocus();
      _verify(code);
    }
  }

  Future<void> _verify(String code) async {
    setState(() {
      _submitting = true;
      _error = false;
    });
    final error = await widget.onVerified(code);
    if (!mounted || error == null) {
      return;
    }
    setState(() => _submitting = false);
    _showError(error);
  }

  Future<void> _resend() async {
    setState(() => _submitting = true);
    final error = await widget.onResend();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (error == null) _seconds = 59;
    });
    _timer?.cancel();
    if (error != null) {
      _showError(error);
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _seconds--);
      }
    });
    showAppSnack(context, 'Звонок запрошен повторно');
  }

  void _showError(String message) {
    setState(() {
      _error = true;
      _errorText = message;
    });
    _shake.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) {
        return;
      }
      for (final controller in _controllers) {
        controller.clear();
      }
      _nodes.first.requestFocus();
    });
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        fixedSize: const Size.fromHeight(54),
        side: BorderSide(
          color: AppColors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: context.text.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.white),
        ),
      ),
    );
  }
}
