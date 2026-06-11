import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A circular avatar showing a person's initials over a color derived from
/// their name, with an optional presence dot (AGENTS.md §1 `core/widgets`).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 18,
    this.color,
    this.statusColor,
  });

  final String name;
  final double radius;
  final Color? color;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: color ?? avatarColor(name),
      child: Text(
        avatarInitials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (statusColor == null) {
      return avatar;
    }
    final double dot = radius * 0.6;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// One or two uppercase initials for [name] (falls back to `U`).
String avatarInitials(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }
  final List<String> parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// A stable accent color for [name] from [AppColors.avatarPalette].
Color avatarColor(String name) {
  if (name.isEmpty) {
    return AppColors.slate;
  }
  final int index = name.codeUnits.fold<int>(0, (int a, int b) => a + b) %
      AppColors.avatarPalette.length;
  return AppColors.avatarPalette[index];
}
