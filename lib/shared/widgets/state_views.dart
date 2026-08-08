import 'package:flutter/material.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'primary_button.dart';

/// Centered loading spinner for full-screen or section loading states.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.6),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: AppTextStyles.bodyMedium(textColor)),
          ],
        ],
      ),
    );
  }
}

/// User-friendly error state with a retry button — used any time a
/// service call fails, instead of letting the screen fail silently.
///
/// Stage B8 — same tinted-icon-circle + fade/slide-in treatment as
/// [EmptyView] (see that class's doc comment for why), so the two
/// states read as one consistent family instead of two different
/// visual languages for "nothing to show" vs. "something went wrong."
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _StateReveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TintedStateIcon(icon: Icons.error_outline_rounded, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium(textColor),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 160,
                  child: PrimaryButton(label: 'Retry', onPressed: onRetry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state placeholder for lists/screens with no data yet.
///
/// Stage B8 — was a bare `Icon` at fixed 0.4 opacity; now a soft
/// tinted circle behind it (the same `.withOpacity(0.12)` convention
/// [MaterialCard]'s search-result tiles and [ProfileScreen]'s
/// `_ProfileTile` already use elsewhere in the app — B6 extended that
/// pattern to Profile, this extends it to every empty state, which is
/// most of the screens in the app), plus a short fade + slight
/// upward-slide entrance using the exact `TweenAnimationBuilder` shape
/// Home's dashboard cards already established in B4/B1
/// (`AppAnimations.medium` + `.standard`), not a new animation
/// pattern. Reused in 29 files across the app, so this one change
/// reaches nearly every list/screen that can be empty.
class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    return Center(
      child: _StateReveal(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TintedStateIcon(icon: icon, color: textColor),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.bodyMedium(textColor)),
          ],
        ),
      ),
    );
  }
}

/// Stage B8 — shared fade + slight-upward-slide entrance for
/// [EmptyView]/[ErrorView], reusing the exact tween shape/constants
/// `home_screen.dart` already established (`AppAnimations.medium` +
/// `.standard`, `Opacity` + `Transform.translate`) rather than
/// inventing a second entrance animation pattern for state views.
class _StateReveal extends StatelessWidget {
  final Widget child;
  const _StateReveal({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppAnimations.medium,
      curve: AppAnimations.standard,
      builder: (context, value, builtChild) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 10), child: builtChild),
      ),
      child: child,
    );
  }
}

/// Stage B8 — the tinted-circle-behind-an-icon treatment shared by
/// [EmptyView] and [ErrorView]. [color] is the icon's own color at
/// full strength; the backdrop circle reuses it at 12% opacity, same
/// ratio the rest of the app already uses for icon tiles.
class _TintedStateIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _TintedStateIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(icon, size: 32, color: color),
    );
  }
}

/// Success/error snackbars — the single place feedback styling lives,
/// so "user-friendly error messages" stays consistent app-wide.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) {
    _show(context, message, AppColors.success, Icons.check_circle_rounded);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppColors.error, Icons.error_rounded);
  }

  static void _show(
      BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
