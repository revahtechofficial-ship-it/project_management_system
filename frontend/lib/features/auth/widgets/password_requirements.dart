import 'package:flutter/material.dart';

import '../../../core/utils/password_policy.dart';

/// A live checklist of the password rules; each turns green as it's satisfied.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final PasswordRule rule in PasswordPolicy.rules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                Icon(
                  rule.satisfiedBy(password)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: rule.satisfiedBy(password)
                      ? Colors.green
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  rule.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: rule.satisfiedBy(password)
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
