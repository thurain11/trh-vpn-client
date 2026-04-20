import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appThemeModeProvider =
    StateNotifierProvider<AppThemeModeController, ThemeMode>(
  (ref) => AppThemeModeController(),
);

class AppThemeModeController extends StateNotifier<ThemeMode> {
  AppThemeModeController() : super(ThemeMode.light) {
    unawaited(_loadSavedThemeMode());
  }

  static const _storageKey = 'app_theme_mode_v1';

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode.name);
  }

  Future<void> _loadSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final mode = ThemeMode.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ThemeMode.light,
    );
    state = mode;
  }
}
