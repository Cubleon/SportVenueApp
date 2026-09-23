import 'package:flutter/material.dart';

import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/sport_surface.dart';

class SportSelectionScreen extends StatefulWidget {
  const SportSelectionScreen({
    super.key,
    required this.sports,
    required this.initialSelection,
    required this.onContinue,
    this.errorMessage,
  });

  final List<Sport> sports;
  final Set<String> initialSelection;
  final Future<void> Function(Set<String>) onContinue;
  final String Function(Object error)? errorMessage;

  @override
  State<SportSelectionScreen> createState() => _SportSelectionScreenState();
}

class _SportSelectionScreenState extends State<SportSelectionScreen> {
  late final Set<String> _selected = Set<String>.from(widget.initialSelection);
  bool _saving = false;

  bool get _canContinue {
    return widget.sports.isNotEmpty &&
        _selected.isNotEmpty &&
        _selected.length <= 6 &&
        !_saving;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Шаг 1 из 2',
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: 0.5,
                      minHeight: 3,
                      backgroundColor: context.colors.border,
                      valueColor: AlwaysStoppedAnimation(context.colors.accent),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Какой спорт?',
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Можно выбрать несколько',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.sports.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Виды спорта пока недоступны',
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.muted,
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      key: const ValueKey('sports-grid'),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: widget.sports.length,
                      itemBuilder: (context, index) {
                        final sport = widget.sports[index];
                        return _SportCard(
                          sport: sport,
                          selected: _selected.contains(sport.id),
                          onTap: _saving ? () {} : () => _toggle(sport.id),
                        );
                      },
                    ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.colors.bg.withValues(alpha: 0),
                    context.colors.bg,
                    context.colors.bg,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: PrimaryButton(
                  key: const ValueKey('sports-continue'),
                  label: _selected.isEmpty
                      ? 'Продолжить'
                      : 'Продолжить · ${_selected.length} ${_selected.length == 1
                            ? 'вид'
                            : _selected.length < 5
                            ? 'вида'
                            : 'видов'}',
                  isLoading: _saving,
                  onPressed: _canContinue ? _save : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < 6) {
        _selected.add(id);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onContinue(Set<String>.from(_selected));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showAppSnack(
        context,
        widget.errorMessage?.call(error) ?? 'Не удалось сохранить выбор',
        tone: SnackTone.failed,
      );
      return;
    }

    if (mounted) {
      setState(() => _saving = false);
    }
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({
    required this.sport,
    required this.selected,
    required this.onTap,
  });

  final Sport sport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: selected ? 0.985 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: withSelectionFeedback(onTap),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? context.colors.accent
                      : context.colors.border,
                  width: selected ? 2.5 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: context.colors.accent.withValues(alpha: 0.22),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SportSurface(sportId: sport.id),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.45, 1],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      sport.name.capitalized,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Sits on the pitch drawing, not on the page.
                      style: context.text.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: ExcludeSemantics(
                      child: SportGlyph(sport: sport, size: 34),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: context.colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: context.colors.ink,
                          size: 18,
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
}
