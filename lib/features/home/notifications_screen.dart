import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';
import '../../models/engagement_models.dart';
import '../../repositories/engagement_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Stage 2 — real notifications list, replacing the home screen's
/// no-op bell icon. Backed by `notifications/{id}` via
/// [NotificationRepository.watchByUser]; tapping an unread notification
/// marks it read in place (optimistic — no reload needed since the
/// screen is stream-driven).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) => switch (type) {
        'community' => Icons.groups_rounded,
        'achievement' => Icons.emoji_events_rounded,
        'exam' => Icons.assignment_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    final bodyColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textColor =
        Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const EmptyView(
          message: 'Sign in to see your notifications.',
          icon: Icons.notifications_off_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationRepository().watchByUser(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: 'Could not load notifications: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LoadingView();
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const EmptyView(
              message: 'No notifications yet.',
              icon: Icons.notifications_none_rounded,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
            itemBuilder: (context, i) {
              final n = items[i];
              return ListTile(
                onTap: () {
                  if (!n.isRead) {
                    NotificationRepository().save(n.copyWith(isRead: true));
                  }
                },
                leading: CircleAvatar(
                  backgroundColor: (n.isRead ? AppColors.textSecondary : AppColors.primaryBlue)
                      .withOpacity(0.12),
                  child: Icon(
                    _iconFor(n.type),
                    color: n.isRead ? AppColors.textSecondary : AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                title: Text(
                  n.title,
                  style: n.isRead
                      ? AppTextStyles.bodyLarge(bodyColor)
                      : AppTextStyles.titleMedium(textColor),
                ),
                subtitle: Text(n.body, style: AppTextStyles.bodySmall(bodyColor)),
                trailing: Text(FormatUtils.relative(n.createdAt), style: AppTextStyles.bodySmall(bodyColor)),
              );
            },
          );
        },
      ),
    );
  }
}
