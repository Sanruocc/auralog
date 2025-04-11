enum SummaryType {
  weekly,
  monthly,
  insights,
  affirmations,
}

class Summary {
  final String id;
  final String userId;
  final String content;
  final SummaryType type;
  final DateTime createdAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool isSynced;

  const Summary({
    required this.id,
    required this.userId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.periodStart,
    required this.periodEnd,
    this.isSynced = false,
  });

  Summary copyWith({
    String? id,
    String? userId,
    String? content,
    SummaryType? type,
    DateTime? createdAt,
    DateTime? periodStart,
    DateTime? periodEnd,
    bool? isSynced,
  }) {
    return Summary(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      type: SummaryType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SummaryType.weekly,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      isSynced: json['is_synced'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Summary &&
        other.id == id &&
        other.userId == userId &&
        other.content == content &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.periodStart == periodStart &&
        other.periodEnd == periodEnd &&
        other.isSynced == isSynced;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      content,
      type,
      createdAt,
      periodStart,
      periodEnd,
      isSynced,
    );
  }
}
