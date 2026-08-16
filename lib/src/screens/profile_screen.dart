import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../theme/app_theme.dart';
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
              title: 'профиль',
              subtitle: controller.isConnected
                  ? 'аккаунт sportvenue'
                  : 'демо-аккаунт sportvenue',
            ),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.accentPressed, AppColors.accent],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _profileInitial(controller),
                        style: context.text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
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
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.phone.isEmpty
                              ? 'номер не указан'
                              : controller.phone,
                          style: context.text.bodySmall?.copyWith(
                            color: AppColors.dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => showAppSnack(
                      context,
                      'редактирование профиля подключится позже',
                    ),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'спортивные предпочтения',
              style: context.text.labelLarge?.copyWith(
                color: AppColors.faint,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.selectedSports
                  .map(
                    (sport) => SelectableChip(
                      label: sport.name,
                      icon: sport.icon,
                      color: sport.color,
                      selected: true,
                      onTap: () => controller.togglePreferredSport(sport.id),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            _Stats(controller: controller),
            const SizedBox(height: 18),
            _MenuItem(
              icon: Icons.history_rounded,
              title: 'история',
              subtitle:
                  '${controller.bookings.length} броней · ${controller.games.length} игр',
              onTap: () => showAppSnack(
                context,
                'полная история появится в следующей версии',
              ),
            ),
            _MenuItem(
              icon: Icons.credit_card_rounded,
              title: 'платежи',
              subtitle: 'карты и транзакции',
              onTap: () => showAppSnack(
                context,
                'платёжные методы будут через эквайринг',
              ),
            ),
            _MenuItem(
              icon: Icons.notifications_active_rounded,
              title: 'уведомления',
              subtitle: 'push, бронь, игры и чат',
              onTap: () =>
                  showAppSnack(context, 'push-уведомления появятся позже'),
            ),
            _MenuItem(
              icon: Icons.support_agent_rounded,
              title: 'поддержка',
              subtitle: 'faq и форма обращения',
              onTap: () =>
                  showAppSnack(context, 'заявка в поддержку создана локально'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              key: const ValueKey('logout-button'),
              label: 'выйти из аккаунта',
              secondary: true,
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
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${controller.bookings.length}',
            label: 'броней',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value:
                '${controller.games.where((game) => game.participants.any((p) => p.isCurrentUser)).length}',
            label: 'моих игр',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '${controller.selectedSports.length}',
            label: 'видов спорта',
          ),
        ),
      ],
    );
  }
}

String _profileInitial(AppController controller) {
  final source = controller.userName?.trim().isNotEmpty == true
      ? controller.userName!.trim()
      : controller.phone.replaceAll(RegExp(r'\D'), '');
  return source.isEmpty ? 'С' : source.characters.first.toUpperCase();
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: AppColors.dim),
          ),
        ],
      ),
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
              height: 42,
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: AppColors.dim,
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
