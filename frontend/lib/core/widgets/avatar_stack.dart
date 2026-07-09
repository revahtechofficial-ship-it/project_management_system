import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// A row of overlapping avatars with a "+N" overflow chip, for showing the
/// members/assignees of a task, project or channel compactly.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    this.imageUrls = const <String?>[],
    this.radius = 12,
    this.max = 4,
  });

  final List<String> names;
  final List<String?> imageUrls;
  final double radius;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (names.isEmpty) {
      return const SizedBox.shrink();
    }
    final int shown = names.length > max ? max : names.length;
    final int extra = names.length - shown;
    final double step = radius * 1.35;
    final double diameter = radius * 2 + 4; // +4 for the ring border.
    final int slots = shown + (extra > 0 ? 1 : 0);
    final double width = diameter + step * (slots - 1);

    Widget ring(Widget child) => Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
      child: child,
    );

    return SizedBox(
      width: width,
      height: diameter,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < shown; i++)
            Positioned(
              left: step * i,
              child: ring(
                UserAvatar(
                  name: names[i],
                  radius: radius,
                  imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: step * shown,
              child: ring(
                CircleAvatar(
                  radius: radius,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: radius * 0.7,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
