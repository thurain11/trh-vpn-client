import '../../domain/entities/subscription_record.dart';

class SubscriptionRecordModel extends SubscriptionRecord {
  const SubscriptionRecordModel({
    required super.id,
    required super.url,
    super.name,
    super.lastSyncedAt,
    super.lastError,
  });

  factory SubscriptionRecordModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionRecordModel(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      name: json['name'] as String?,
      lastSyncedAt: _parseDateTime(json['lastSyncedAt'] as String?),
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  SubscriptionRecord toEntity() {
    return SubscriptionRecord(
      id: id,
      url: url,
      name: name,
      lastSyncedAt: lastSyncedAt,
      lastError: lastError,
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
