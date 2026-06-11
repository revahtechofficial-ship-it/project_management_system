/// A single password requirement, with a label and a test, for live UI feedback.
class PasswordRule {
  const PasswordRule(this.label, this.satisfiedBy);

  final String label;
  final bool Function(String) satisfiedBy;
}

/// Client-side mirror of the backend password policy (AGENTS.md §9 — keep the
/// rules in one place). The backend remains the source of truth.
class PasswordPolicy {
  const PasswordPolicy._();

  static final List<PasswordRule> rules = <PasswordRule>[
    PasswordRule('At least 8 characters', (p) => p.length >= 8),
    PasswordRule('One uppercase letter', (p) => p.contains(RegExp('[A-Z]'))),
    PasswordRule('One lowercase letter', (p) => p.contains(RegExp('[a-z]'))),
    PasswordRule('One number', (p) => p.contains(RegExp('[0-9]'))),
    PasswordRule(
      'One special character',
      (p) => p.contains(RegExp(r'[^A-Za-z0-9]')),
    ),
  ];

  /// Whether the password satisfies every rule.
  static bool isValid(String pw) => rules.every((r) => r.satisfiedBy(pw));
}
