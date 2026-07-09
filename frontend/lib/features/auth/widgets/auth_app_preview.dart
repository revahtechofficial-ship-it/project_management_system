import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A stylised mini-mockup of the app (a grouped task list), used as the auth
/// showcase graphic. It illustrates the product's own UI language — status
/// pills, labels, priorities — with neutral placeholder rows.
class AuthAppPreview extends StatelessWidget {
  const AuthAppPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 50,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Toolbar(scheme: scheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _Group(label: 'Done', color: AppColors.green, count: 2),
                  const _Row(
                    done: true,
                    title: 'Design system v2',
                    label: 'Design',
                    labelColor: AppColors.violet,
                  ),
                  const _Row(
                    done: true,
                    title: 'Onboarding flow',
                    label: 'Product',
                    labelColor: AppColors.sky,
                  ),
                  const SizedBox(height: 14),
                  const _Group(
                    label: 'In progress',
                    color: AppColors.brand,
                    count: 3,
                  ),
                  const _Row(
                    done: false,
                    title: 'API integration',
                    label: 'Engineering',
                    labelColor: AppColors.teal,
                    flag: AppColors.rose,
                  ),
                  const _Row(
                    done: false,
                    title: 'Q3 roadmap',
                    label: 'Planning',
                    labelColor: AppColors.amber,
                  ),
                  const _Row(
                    done: false,
                    title: 'User research',
                    label: 'Research',
                    labelColor: AppColors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Marketing',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 14),
          _Tab(label: 'List', active: true, scheme: scheme),
          _Tab(label: 'Board', active: false, scheme: scheme),
          _Tab(label: 'Gantt', active: false, scheme: scheme),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.scheme});
  final String label;
  final bool active;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brand.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.brand : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.color, required this.count});
  final String label;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.done,
    required this.title,
    required this.label,
    required this.labelColor,
    this.flag,
  });

  final bool done;
  final String title;
  final String label;
  final Color labelColor;
  final Color? flag;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 17,
            color: done ? AppColors.green : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: flag != null
                ? Icon(Icons.flag_rounded, size: 14, color: flag)
                : null,
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppColors.shade(labelColor),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
