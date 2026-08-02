import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Small dot or count badge, typically layered on an icon (e.g. the
/// notification bell). Wraps [child] in a [Stack] so callers don't
/// re-implement the Positioned math each time.
class AppBadge extends StatelessWidget {
  final Widget child;
  final int? count;
  final bool showDot;
  final Color color;

  const AppBadge({
    super.key,
    required this.child,
    this.count,
    this.showDot = false,
    this.color = AppColors.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasCount = count != null && count! > 0;
    if (!hasCount && !showDot) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: hasCount ? -4 : 6,
          top: hasCount ? -4 : 6,
          child: Container(
            padding: hasCount
                ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
                : EdgeInsets.zero,
            constraints: hasCount
                ? const BoxConstraints(minWidth: 16, minHeight: 16)
                : const BoxConstraints(minWidth: 8, minHeight: 8),
            decoration: BoxDecoration(
              color: color,
              shape: hasCount ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: hasCount ? BorderRadius.circular(8) : null,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: hasCount
                ? Text(
                    count! > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
