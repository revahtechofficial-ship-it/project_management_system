import '../enums/asset_kind.dart';
import '../enums/asset_status.dart';

/// One item in the company inventory — a laptop, a software subscription or a
/// license, from `/api/v1/assets`. Manual JSON serialization per AGENTS.md §9.
class Asset {
  final int id;
  final String name;
  final AssetKind kind;
  final AssetStatus status;
  final String identifier;
  final String vendor;
  final int? assigneeId;
  final String assigneeName;
  final int costCents;
  final DateTime? purchasedOn;
  final DateTime? expiresOn;
  final String notes;
  final DateTime createdAt;

  const Asset({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.kind = AssetKind.hardware,
    this.status = AssetStatus.available,
    this.identifier = '',
    this.vendor = '',
    this.assigneeId,
    this.assigneeName = '',
    this.costCents = 0,
    this.purchasedOn,
    this.expiresOn,
    this.notes = '',
  });

  /// Purchase cost in whole currency units (cents / 100).
  double get cost => costCents / 100;

  /// True when the asset has an expiry within the next 30 days (or already
  /// past) — used to flag licenses and warranties that need renewal.
  bool get expiringSoon {
    final DateTime? e = expiresOn;
    if (e == null) {
      return false;
    }
    return e.difference(DateTime.now()).inDays <= 30;
  }

  static DateTime? _date(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    kind: AssetKind.fromJson(json['kind'] as String? ?? 'hardware'),
    status: AssetStatus.fromJson(json['status'] as String? ?? 'available'),
    identifier: json['identifier'] as String? ?? '',
    vendor: json['vendor'] as String? ?? '',
    assigneeId: json['assignee_id'] as int?,
    assigneeName: json['assignee_name'] as String? ?? '',
    costCents: json['cost_cents'] as int? ?? 0,
    purchasedOn: _date(json['purchased_on']),
    expiresOn: _date(json['expires_on']),
    notes: json['notes'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'kind': kind.toJson(),
    'status': status.toJson(),
    'identifier': identifier,
    'vendor': vendor,
    'assignee_id': assigneeId,
    'assignee_name': assigneeName,
    'cost_cents': costCents,
    'purchased_on': purchasedOn?.toIso8601String(),
    'expires_on': expiresOn?.toIso8601String(),
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'Asset(id: $id, name: $name, kind: ${kind.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Asset &&
          other.id == id &&
          other.name == name &&
          other.kind == kind &&
          other.status == status &&
          other.identifier == identifier &&
          other.vendor == vendor &&
          other.assigneeId == assigneeId &&
          other.assigneeName == assigneeName &&
          other.costCents == costCents &&
          other.purchasedOn == purchasedOn &&
          other.expiresOn == expiresOn &&
          other.notes == notes &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    status,
    identifier,
    vendor,
    assigneeId,
    assigneeName,
    costCents,
    purchasedOn,
    expiresOn,
    notes,
    createdAt,
  );
}
