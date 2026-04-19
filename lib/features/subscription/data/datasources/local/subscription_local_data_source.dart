import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/subscription_record_model.dart';

abstract class SubscriptionLocalDataSource {
  Future<SubscriptionRecordModel?> getPrimary();
  Future<void> savePrimary(SubscriptionRecordModel subscription);
}

class SharedPrefsSubscriptionLocalDataSource
    implements SubscriptionLocalDataSource {
  SharedPrefsSubscriptionLocalDataSource({
    Future<SharedPreferences>? sharedPreferences,
  }) : _sharedPreferences = sharedPreferences ?? SharedPreferences.getInstance();

  static const _subscriptionKey = 'subscription_primary_v1';
  final Future<SharedPreferences> _sharedPreferences;

  @override
  Future<SubscriptionRecordModel?> getPrimary() async {
    final prefs = await _sharedPreferences;
    final raw = prefs.getString(_subscriptionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return null;
      }
      return SubscriptionRecordModel.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePrimary(SubscriptionRecordModel subscription) async {
    final prefs = await _sharedPreferences;
    await prefs.setString(_subscriptionKey, jsonEncode(subscription.toJson()));
  }
}
