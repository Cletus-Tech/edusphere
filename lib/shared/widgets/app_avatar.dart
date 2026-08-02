import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Circular user avatar. Falls back to initials (or a person icon if no
/// name is available) so it never renders a broken image, and never
/// needs the caller to know whether a photo URL exists.
class AppAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double radius;

  const AppAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.radius = 20,
  });

  String? get _initials {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }

    final initials = _initials;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryBlue,
      child: initials != null
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.7,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            )
          : Icon(Icons.person, color: Colors.white, size: radius),
    );
  }
}
