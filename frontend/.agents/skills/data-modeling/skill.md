# Flutter Data Modeling Skill

## Description
Canonical reference implementations for the data layer. Load this skill when
writing a data model (manual JSON serialization) or an enum. The **rules** live
in AGENTS.md (Application Architecture → Data Handling & Serialization, and
Enums); this skill is the worked code to copy from.

## Data Class — Manual JSON Serialization
Demonstrates a `const` constructor, safe defaults, manual `fromJson` / `toJson`
for nested models and lists (via the `jsonToObj` / `jsonToList` helpers), and
`toString` / `==` / `hashCode` overrides.

```dart
import 'package:flutter/foundation.dart'; // listEquals
// Relative import: this model lives in lib/data/models/.
import '../../core/extensions/dynamic_extension.dart';

// `Address` and `Role` are sibling data classes following this pattern.
class User {
  final String id;
  final bool isActive;
  final String firstName;
  final int total;
  final Address address; // non-nullable nested model
  final Address? billingAddress; // nullable nested model
  final List<Role> roles; // list of nested models

  const User({
    required this.id,
    required this.isActive,
    this.firstName = '',
    this.total = 0,
    this.address = const Address(),
    this.billingAddress,
    this.roles = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        isActive: json['is_active'] as bool,
        firstName: json['first_name'] as String? ?? '',
        total: json['total'] as int? ?? 0,
        // Non-nullable nested model: jsonToObj + const fallback.
        address: jsonToObj<Address>(
              data: json['address'],
              generator: (map) => Address.fromJson(map),
            ) ??
            const Address(),
        // Nullable nested model: jsonToObj, no fallback (stays null).
        billingAddress: jsonToObj<Address>(
          data: json['billing_address'],
          generator: (map) => Address.fromJson(map),
        ),
        // List of models: jsonToList always returns a non-null List<Role>.
        roles: jsonToList<Role>(
          data: json['roles'],
          generator: (map) => Role.fromJson(map),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'is_active': isActive,
        'first_name': firstName,
        'total': total,
        'address': address.toJson(),
        'billing_address': billingAddress?.toJson(),
        'roles': roles.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() => 'User('
      'id: $id, '
      'isActive: $isActive, '
      'firstName: $firstName, '
      'total: $total, '
      'address: $address, '
      'billingAddress: $billingAddress, '
      'roles: $roles'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          other.id == id &&
          other.isActive == isActive &&
          other.firstName == firstName &&
          other.total == total &&
          other.address == address &&
          other.billingAddress == billingAddress &&
          listEquals(other.roles, roles);

  @override
  int get hashCode => Object.hash(
        id,
        isActive,
        firstName,
        total,
        address,
        billingAddress,
        Object.hashAll(roles),
      );
}
```

## Enums
Enums tied to a data class carry `toJson` / `fromJson` (with a sentinel default);
enums not tied to a data class carry only the helpers they need (and use
`fromString`, not `fromJson`, for local non-API strings).

```dart
// lib/data/enums/gender.dart
// Data-class enum: has toJson / fromJson.
// `inCaps` is a String extension in lib/core/extensions/.
enum Gender {
  male,
  female,
  other; // sentinel / fallback

  String get label => name.inCaps;

  String toJson() => switch (this) {
        Gender.male => 'male',
        Gender.female => 'female',
        _ => 'other',
      };

  factory Gender.fromJson(String value) => switch (value) {
        'male' => Gender.male,
        'female' => Gender.female,
        _ => Gender.other,
      };
}
```

```dart
// lib/data/enums/nav_bar_item.dart
// Navigation only: icon + label + route, no JSON.
enum NavBarItems {
  home,
  transaction,
  profile;

  IconData get icon => switch (this) {
        NavBarItems.home => Icons.home,
        NavBarItems.transaction => Icons.wallet,
        NavBarItems.profile => Icons.person,
      };

  String get label => name.inCaps;

  String get route => switch (this) {
        NavBarItems.home => HomePage.route,
        NavBarItems.transaction => TransactionPage.route,
        NavBarItems.profile => ProfilePage.route,
      };
}
```

```dart
// lib/data/enums/category_type.dart
// List filtering only: fromString, not fromJson.
enum CategoryType {
  income,
  expense;

  String get label => name.inCaps;

  Color get color => switch (this) {
        CategoryType.income => AppColors.emerald700,
        CategoryType.expense => AppColors.red700,
      };

  String get sign => switch (this) {
        CategoryType.income => '+',
        CategoryType.expense => '-',
      };

  factory CategoryType.fromString(String value) => switch (value) {
        'income' => CategoryType.income,
        _ => CategoryType.expense,
      };
}
```
