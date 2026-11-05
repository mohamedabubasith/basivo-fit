import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme preference (system / light / dark), saved on the device.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _mode = ThemeMode.values.firstWhere((m) => m.name == p.getString('theme'), orElse: () => ThemeMode.system);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString('theme', m.name);
    } catch (_) {}
  }
}
