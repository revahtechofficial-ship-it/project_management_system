import 'package:flutter/material.dart';

import '../constants/app_images.dart';

/// The official Revah Tech wordmark.
///
/// The source asset is a white silhouette, so by default it is recolored to the
/// surface's foreground (`onSurface`) — dark on light themes, white on dark —
/// keeping it readable everywhere. Pass [color] to force a specific tint (e.g.
/// `Colors.white` over a gradient).
class RevahLogo extends StatelessWidget {
  const RevahLogo({super.key, this.height = 26, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? Theme.of(context).colorScheme.onSurface;
    return Image.asset(
      AppImages.revahLogo,
      height: height,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
