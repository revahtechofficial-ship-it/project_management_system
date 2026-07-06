/// One line item on an [Invoice], from `/api/v1/invoices/{id}`. Manual JSON
/// serialization per AGENTS.md §9.
class InvoiceLine {
  final int id;
  final String description;
  final int quantityMinutes;
  final int rateCents;
  final int amountCents;

  const InvoiceLine({
    required this.id,
    this.description = '',
    this.quantityMinutes = 0,
    this.rateCents = 0,
    this.amountCents = 0,
  });

  /// Billed hours, when the line represents time (0 for flat-fee lines).
  double get hours => quantityMinutes / 60;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) => InvoiceLine(
        id: json['id'] as int,
        description: json['description'] as String? ?? '',
        quantityMinutes: json['quantity_minutes'] as int? ?? 0,
        rateCents: json['rate_cents'] as int? ?? 0,
        amountCents: json['amount_cents'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'description': description,
        'quantity_minutes': quantityMinutes,
        'rate_cents': rateCents,
        'amount_cents': amountCents,
      };

  @override
  String toString() => 'InvoiceLine(id: $id, $description: $amountCents)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceLine &&
          other.id == id &&
          other.description == description &&
          other.quantityMinutes == quantityMinutes &&
          other.rateCents == rateCents &&
          other.amountCents == amountCents;

  @override
  int get hashCode =>
      Object.hash(id, description, quantityMinutes, rateCents, amountCents);
}
