import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_provider.dart';
import '../../shared/dialogs/app_dialog.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../admin/admin_dashboard_screen.dart';
import '../creator_profile/creator_profile_screen.dart';
import 'academic_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue.",
      confirmLabel: 'Log out',
      isDestructive: true,
    );

    if (confirmed != true || !context.mounted) return;

    await AuthService().signOut();
    if (!context.mounted) return;
    AppSnackbar.success(context, 'Logged out successfully.');
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ??
        AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    final user = AuthService().currentUser;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              AppAvatar(
                photoUrl: user?.photoURL,
                name: user?.displayName,
                radius: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? 'Guest User',
                        style: AppTextStyles.headlineSmall(textColor)),
                    const SizedBox(height: 2),
                    Text(user?.email ?? 'Not signed in',
                        style: AppTextStyles.bodySmall(bodyColor)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text("Settings isn't available yet."),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          const _ThemeSwitcher(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Account'),
          const SizedBox(height: 12),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const _ProfileTile(
                    icon: Icons.download_outlined, label: 'My Downloads'),
                _divider(),
                const _ProfileTile(icon: Icons.note_outlined, label: 'My Notes'),
                _divider(),
                const _ProfileTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'My Certificates'),
                _divider(),
                _ProfileTile(
                  icon: Icons.account_tree_outlined,
                  label: 'Academic Profile',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AcademicProfileScreen()),
                  ),
                ),
                _divider(),
                const _ProfileTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support'),
                _divider(),
                // Stage 6.3 — Creator Profile ("About the Owner") entry
                // point. Same onTap/MaterialPageRoute wiring as
                // "Academic Profile" above, not a named route — matches
                // how every other detail screen in this app is pushed.
                _ProfileTile(
                  icon: Icons.badge_outlined,
                  label: 'About EduSphere',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatorProfileScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AdminEntryPoint(uid: user?.uid),
          CustomCard(
            padding: EdgeInsets.zero,
            child: _ProfileTile(
              icon: Icons.logout_rounded,
              label: 'Logout',
              color: AppColors.error,
              onTap: () => _handleLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56);
}

/// Shows an "Admin Dashboard" tile only for a signed-in user holding at
/// least one elevated `UserRole` (admin/superAdmin/institutionAdmin/
/// moderator — see `UserRole.isElevated`'s own doc comment, which
/// already described this exact use case but had no caller until now).
/// Renders nothing for a guest/student, and nothing while the profile
/// is still loading — no loading flicker for what most users will never
/// see anyway.
class _AdminEntryPoint extends StatelessWidget {
  final String? uid;
  const _AdminEntryPoint({required this.uid});

  @override
  Widget build(BuildContext context) {
    final id = uid;
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<UserModel?>(
      stream: UserRepository().watchUser(id),
      builder: (context, snapshot) {
        final roles = snapshot.data?.roles ?? const {};
        if (!roles.any((r) => r.isElevated)) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CustomCard(
            padding: EdgeInsets.zero,
            child: _ProfileTile(
              icon: Icons.admin_panel_settings_rounded,
              label: 'Admin Dashboard',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return CustomCard(
      child: Column(
        children: AppThemeMode.values.map((mode) {
          final label = switch (mode) {
            AppThemeMode.light => 'Light',
            AppThemeMode.dark => 'Dark',
            AppThemeMode.system => 'Follow System',
          };
          final icon = switch (mode) {
            AppThemeMode.light => Icons.light_mode_outlined,
            AppThemeMode.dark => Icons.dark_mode_outlined,
            AppThemeMode.system => Icons.brightness_auto_outlined,
          };
          return RadioListTile<AppThemeMode>(
            contentPadding: EdgeInsets.zero,
            value: mode,
            groupValue: themeProvider.mode,
            onChanged: (m) {
              if (m != null) themeProvider.setMode(m);
            },
            title: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 10),
                Text(label),
              ],
            ),
            activeColor: AppColors.primaryBlue,
          );
        }).toList(),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ??
        Theme.of(context).textTheme.bodyLarge?.color ??
        AppColors.textPrimary;

    return ListTile(
      onTap: onTap ?? () {},
      leading: Icon(icon, color: textColor, size: 22),
      title: Text(label, style: AppTextStyles.bodyLarge(textColor)),
      trailing: color == null
          ? const Icon(Icons.chevron_right_rounded, size: 20)
          : null,
    );
  }
}
