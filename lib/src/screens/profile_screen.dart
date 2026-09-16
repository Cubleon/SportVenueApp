import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'sport_selection_screen.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.controller,
    required this.onLogout,
  });

  final AppController controller;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          key: const ValueKey('profile-screen'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
          children: [
            ScreenTitleBar(
              title: 'Профиль',
              subtitle: controller.isConnected
                  ? 'Аккаунт SportVenue'
                  : 'Демо-аккаунт SportVenue',
            ),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                    child: Center(
                      child: Text(
                        _profileInitial(controller),
                        style: context.text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.userName?.trim().isNotEmpty == true
                              ? controller.userName!
                              : 'Пользователь SportVenue',
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.phone.isEmpty
                              ? 'Номер не указан'
                              : controller.phone,
                          style: context.text.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => showAppSnack(
                      context,
                      'Редактирование профиля подключится позже',
                    ),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Спортивные предпочтения',
                    style: context.text.labelLarge?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('edit-sports'),
                  onPressed: () => _editSports(context, controller),
                  child: const Text('Изменить'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.selectedSports
                  .map(
                    (sport) => SelectableChip(
                      label: sport.name.capitalized,
                      icon: sport.icon,
                      selected: true,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            _Stats(controller: controller),
            const SizedBox(height: 18),
            _MenuItem(
              icon: Icons.history_rounded,
              title: 'История',
              subtitle:
                  '${controller.bookings.length} броней · ${controller.games.length} игр',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(controller: controller),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.credit_card_rounded,
              title: 'Платежи',
              subtitle: 'Карты и транзакции',
              onTap: () => showAppSnack(
                context,
                'Платёжные методы будут через эквайринг',
              ),
            ),
            _MenuItem(
              icon: Icons.notifications_active_rounded,
              title: 'Уведомления',
              subtitle: 'push, бронь, игры и чат',
              onTap: () =>
                  showAppSnack(context, 'push-уведомления появятся позже'),
            ),
            _MenuItem(
              icon: Icons.support_agent_rounded,
              title: 'Поддержка',
              subtitle: 'faq и форма обращения',
              onTap: () =>
                  showAppSnack(context, 'Заявка в поддержку создана локально'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              key: const ValueKey('logout-button'),
              label: 'Выйти из аккаунта',
              tone: ButtonTone.neutral,
              onPressed: onLogout,
            ),
          ],
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final games = controller.games
        .where((game) => game.participants.any((p) => p.isCurrentUser))
        .length;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _Stat(value: '${controller.bookings.length}', label: 'Броней'),
          ),
          Expanded(child: _Stat(value: '$games', label: 'Моих игр')),
          Expanded(
            child: _Stat(
              value: '${controller.selectedSports.length}',
              label: 'Видов спорта',
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _editSports(
  BuildContext context,
  AppController controller,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SportSelectionScreen(
        sports: controller.sports,
        initialSelection: controller.selectedSportIds,
        onContinue: (ids) async {
          await controller.completeSports(ids);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    ),
  );
}

String _profileInitial(AppController controller) {
  final source = controller.userName?.trim().isNotEmpty == true
      ? controller.userName!.trim()
      : controller.phone.replaceAll(RegExp(r'\D'), '');
  return source.isEmpty ? 'С' : source.characters.first.toUpperCase();
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}


class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.dim),
          ],
        ),
      ),
    );
  }
}
