/// One completed task plotted on the control chart, from
/// `/api/v1/metrics/cycle-time`. Manual JSON serialization per AGENTS.md §9.
class CyclePoint {
  final int id;
  final String title;
  final DateTime completedAt;
  final double leadDays;
  final double? cycleDays;

  const CyclePoint({
    required this.id,
    required this.completedAt,
    this.title = '',
    this.leadDays = 0,
    this.cycleDays,
  });

  factory CyclePoint.fromJson(Map<String, dynamic> json) => CyclePoint(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    completedAt: DateTime.parse(json['completed_at'] as String),
    leadDays: (json['lead_days'] as num?)?.toDouble() ?? 0,
    cycleDays: (json['cycle_days'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'completed_at': completedAt.toIso8601String(),
    'lead_days': leadDays,
    'cycle_days': cycleDays,
  };

  @override
  String toString() => 'CyclePoint(id: $id, lead: $leadDays)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CyclePoint &&
          other.id == id &&
          other.title == title &&
          other.completedAt == completedAt &&
          other.leadDays == leadDays &&
          other.cycleDays == cycleDays;

  @override
  int get hashCode => Object.hash(id, title, completedAt, leadDays, cycleDays);
}

/// Delivery metrics derived from task completion times: cycle time, lead time
/// and throughput, plus the per-task series for a control chart. Manual JSON
/// serialization per AGENTS.md §9.
class CycleMetrics {
  final int completedCount;
  final int days;
  final double avgLeadDays;
  final double medianLeadDays;
  final double p85LeadDays;
  final double avgCycleDays;
  final double throughputPerWeek;
  final List<CyclePoint> points;

  const CycleMetrics({
    this.completedCount = 0,
    this.days = 90,
    this.avgLeadDays = 0,
    this.medianLeadDays = 0,
    this.p85LeadDays = 0,
    this.avgCycleDays = 0,
    this.throughputPerWeek = 0,
    this.points = const <CyclePoint>[],
  });

  factory CycleMetrics.fromJson(Map<String, dynamic> json) => CycleMetrics(
    completedCount: json['completed_count'] as int? ?? 0,
    days: json['days'] as int? ?? 90,
    avgLeadDays: (json['avg_lead_days'] as num?)?.toDouble() ?? 0,
    medianLeadDays: (json['median_lead_days'] as num?)?.toDouble() ?? 0,
    p85LeadDays: (json['p85_lead_days'] as num?)?.toDouble() ?? 0,
    avgCycleDays: (json['avg_cycle_days'] as num?)?.toDouble() ?? 0,
    throughputPerWeek: (json['throughput_per_week'] as num?)?.toDouble() ?? 0,
    points: <CyclePoint>[
      for (final dynamic e in (json['points'] as List<dynamic>? ?? <dynamic>[]))
        CyclePoint.fromJson(e as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'completed_count': completedCount,
    'days': days,
    'avg_lead_days': avgLeadDays,
    'median_lead_days': medianLeadDays,
    'p85_lead_days': p85LeadDays,
    'avg_cycle_days': avgCycleDays,
    'throughput_per_week': throughputPerWeek,
    'points': points.map((CyclePoint p) => p.toJson()).toList(),
  };

  @override
  String toString() =>
      'CycleMetrics(count: $completedCount, avgLead: $avgLeadDays)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleMetrics &&
          other.completedCount == completedCount &&
          other.days == days &&
          other.avgLeadDays == avgLeadDays &&
          other.medianLeadDays == medianLeadDays &&
          other.p85LeadDays == p85LeadDays &&
          other.avgCycleDays == avgCycleDays &&
          other.throughputPerWeek == throughputPerWeek;

  @override
  int get hashCode => Object.hash(
    completedCount,
    days,
    avgLeadDays,
    medianLeadDays,
    p85LeadDays,
    avgCycleDays,
    throughputPerWeek,
    Object.hashAll(points),
  );
}
