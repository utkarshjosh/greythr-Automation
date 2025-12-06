class ScheduleConfig {
  final String cron;
  final bool enabled;
  final String description;
  final String? createdAt;
  final String? updatedAt;

  ScheduleConfig({
    required this.cron,
    required this.enabled,
    required this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleConfig.fromMap(Map<String, dynamic> map) {
    return ScheduleConfig(
      cron: map['cron'] ?? '0 9 * * *',
      enabled: map['enabled'] ?? true,
      description: map['description'] ?? 'Daily automation',
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cron': cron,
      'enabled': enabled,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ScheduleConfig copyWith({
    String? cron,
    bool? enabled,
    String? description,
    String? createdAt,
    String? updatedAt,
  }) {
    return ScheduleConfig(
      cron: cron ?? this.cron,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}



