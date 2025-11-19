import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeService();
  static const _prefKey = 'theme_is_light';
  bool _isLight = false;
  Map<String, dynamic>? _themeJson;

  bool get isLight => _isLight;
  Map<String, dynamic>? get themeJson => _themeJson;

  final Map<String, String> _overrides = {};
  static const _overridesKey = 'theme_page_overrides';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLight = prefs.getBool(_prefKey) ?? false;
    await _loadJson();
    await _loadOverrides();
    notifyListeners();
  }

  Future<void> _loadJson() async {
    if (_themeJson != null) return;
    try {
      final s = await rootBundle.loadString(
        'lib/assets/theme/theme-light.json',
      );
      _themeJson = jsonDecode(s) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('ThemeService: failed to load theme JSON: $e');
      _themeJson = null;
    }
  }

  Future<void> _loadOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_overridesKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> parsed =
            jsonDecode(raw) as Map<String, dynamic>;
        _overrides.clear();
        parsed.forEach((k, v) {
          if (v is String) _overrides[k] = v;
        });
      }
    } catch (_) {}
  }

  String imageForPage(String pageId, {String fallback = ''}) {
    try {
      final override = _overrides[pageId];
      if (override != null && override.isNotEmpty) {
        return 'lib/assets/backgrounds/$override.png';
      }
      final pages = _themeJson?['pages'] as Map<String, dynamic>?;
      if (pages != null) {
        final pageObj = pages[pageId] as Map<String, dynamic>?;
        if (pageObj != null) {
          final key =
              _isLight
                  ? (pageObj['light'] as String?)
                  : (pageObj['default'] as String?);
          if (key != null && key.isNotEmpty) {
            return 'lib/assets/backgrounds/$key.png';
          }
        }
      }
    } catch (_) {}
    return fallback;
  }

  void setPageBackground(String pageId, String imageName) {
    _overrides[pageId] = imageName;
    _saveOverrides();
    notifyListeners();
  }

  void togglePageBackground(
    String pageId,
    String aImageName,
    String bImageName,
  ) {
    final cur = _overrides[pageId];
    if (cur == aImageName) {
      _overrides[pageId] = bImageName;
    } else if (cur == bImageName) {
      _overrides[pageId] = aImageName;
    } else {
      _overrides[pageId] = aImageName;
    }
    _saveOverrides();
    notifyListeners();
  }

  Future<void> _saveOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_overridesKey, jsonEncode(_overrides));
    } catch (_) {}
  }

  String? getPageOverride(String pageId) => _overrides[pageId];

  Future<void> clearPageOverride(String pageId) async {
    _overrides.remove(pageId);
    await _saveOverrides();
    notifyListeners();
  }

  Future<void> clearAllOverrides() async {
    _overrides.clear();
    await _saveOverrides();
    notifyListeners();
  }

  String colorFor(String key, {String fallback = ''}) {
    try {
      final colors = _themeJson?['colors'] as Map<String, dynamic>?;
      final c = colors != null ? colors[key] as String? : null;
      if (c != null) return c;
    } catch (_) {}
    return fallback;
  }

  Future<void> setLight(bool value, {bool clearOverrides = false}) async {
    _isLight = value;
    if (clearOverrides) {
      _overrides.clear();
      await _saveOverrides();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    notifyListeners();
  }

  Future<void> toggle({bool clearOverrides = false}) async {
    await setLight(!_isLight, clearOverrides: clearOverrides);
  }
}
