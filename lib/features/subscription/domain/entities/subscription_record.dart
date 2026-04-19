class SubscriptionRecord {
  const SubscriptionRecord({
    required this.id,
    required this.url,
    this.name,
    this.lastSyncedAt,
    this.lastError,
  });

  final String id;
  final String url;
  final String? name;
  final DateTime? lastSyncedAt;
  final String? lastError;
}
