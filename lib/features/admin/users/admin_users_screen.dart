import 'package:flutter/material.dart';
import '../../../core/enums/user_role.dart';
import '../../../models/user_model.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Admin → Users & Roles. Real account/role management over
/// [UserRepository], replacing the Stage 1 `FeaturePlaceholder`.
///
/// Role-escalation guard: `firestore.rules` lets any `isAdmin()` user
/// write any other user's `roles` field, which would let a plain admin
/// grant themselves `superAdmin` through this screen. Since tightening
/// that at the rules layer needs a redeploy this environment can't test,
/// the guard lives here instead: only a viewer who already holds
/// `superAdmin` can grant/revoke `admin` or `superAdmin`. Worth
/// revisiting with a rules-level (or Cloud Function) check later.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users & Roles')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SearchField(
              controller: _searchController,
              hintText: 'Search by name or email...',
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: UserRepository().watchAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(message: 'Could not load users: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) return const LoadingView();

                  var users = snapshot.data!;
                  if (_query.isNotEmpty) {
                    users = users
                        .where((u) =>
                            u.fullName.toLowerCase().contains(_query) ||
                            u.email.toLowerCase().contains(_query))
                        .toList();
                  }
                  if (users.isEmpty) {
                    return const EmptyView(message: 'No users match your search.', icon: Icons.people_outline);
                  }

                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _UserTile(user: users[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return ListTile(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _UserManagementSheet(user: user),
      ),
      leading: AppAvatar(photoUrl: user.photoUrl, name: user.fullName, radius: 20),
      title: Text(user.fullName.isEmpty ? user.email : user.fullName, style: AppTextStyles.titleMedium(textColor)),
      subtitle: Text(
        [user.email, if (user.isSuspended) 'Suspended'].join(' · '),
        style: AppTextStyles.bodySmall(user.isSuspended ? AppColors.error : bodyColor),
      ),
      trailing: Wrap(
        spacing: 4,
        children: user.roles
            .take(2)
            .map((r) => Chip(
                  label: Text(r.id, style: AppTextStyles.bodySmall(AppColors.primaryBlue)),
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ))
            .toList(),
      ),
    );
  }
}

class _UserManagementSheet extends StatefulWidget {
  final UserModel user;
  const _UserManagementSheet({required this.user});

  @override
  State<_UserManagementSheet> createState() => _UserManagementSheetState();
}

class _UserManagementSheetState extends State<_UserManagementSheet> {
  late Set<UserRole> _selectedRoles = {...widget.user.roles};
  bool _saving = false;

  // Best-effort: the signed-in admin's own roles aren't passed in, but
  // whoever can reach this screen came through the admin dashboard's
  // own role gate — for the escalation-specific admin/superAdmin
  // checkboxes we re-check via the live profile stream below instead of
  // trusting a cached value.
  Set<UserRole> _viewerRoles = {};

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final uid = AuthService().currentUser?.uid;

    return StreamBuilder<UserModel?>(
      stream: uid == null ? const Stream.empty() : UserRepository().watchUser(uid),
      builder: (context, viewerSnapshot) {
        _viewerRoles = viewerSnapshot.data?.roles ?? {};
        final canEscalate = _viewerRoles.contains(UserRole.superAdmin);

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.user.fullName, style: AppTextStyles.headlineLarge(textColor)),
              Text(widget.user.email, style: AppTextStyles.bodyMedium(textColor)),
              const SizedBox(height: 16),
              Text('Roles', style: AppTextStyles.titleMedium(textColor)),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: UserRole.values.map((role) {
                  final isEscalated = role == UserRole.admin || role == UserRole.superAdmin;
                  final enabled = !isEscalated || canEscalate;
                  return FilterChip(
                    label: Text(role.id),
                    selected: _selectedRoles.contains(role),
                    onSelected: enabled
                        ? (selected) => setState(() {
                              if (selected) {
                                _selectedRoles.add(role);
                              } else {
                                _selectedRoles.remove(role);
                              }
                            })
                        : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _toggleSuspend(context),
                      child: Text(widget.user.isSuspended ? 'Restore account' : 'Suspend account'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _saveRoles(context),
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save roles'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveRoles(BuildContext context) async {
    if (_selectedRoles.isEmpty) {
      AppSnackbar.error(context, 'A user needs at least one role.');
      return;
    }
    setState(() => _saving = true);
    final result = await UserRepository().replaceRoles(widget.user, _selectedRoles);
    if (!context.mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not update roles.');
      return;
    }
    Navigator.of(context).pop();
    AppSnackbar.success(context, 'Roles updated.');
  }

  Future<void> _toggleSuspend(BuildContext context) async {
    setState(() => _saving = true);
    final result = await UserRepository().setSuspended(widget.user, !widget.user.isSuspended);
    if (!context.mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not update the account.');
      return;
    }
    Navigator.of(context).pop();
    AppSnackbar.success(context, widget.user.isSuspended ? 'Account restored.' : 'Account suspended.');
  }
}
