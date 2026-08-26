import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GAME MODE
// ═══════════════════════════════════════════════════════════════════════════════

/// The game mode selected by the player.
enum GameMode {
  /// Standard Cubicles rules — level up every 10 lines, classic speed curve.
  classic,

  /// Faster fall speed at every level (×1.35 multiplier applied to the speed).
  speed,

  /// Level up every 25 lines instead of 10 — longer, endurance-style games.
  marathon,
}

extension GameModeLabel on GameMode {
  String get label {
    switch (this) {
      case GameMode.classic:  return 'Classic';
      case GameMode.speed:    return 'Speed';
      case GameMode.marathon: return 'Marathon';
    }
  }

  String get description {
    switch (this) {
      case GameMode.classic:  return 'Standard rules';
      case GameMode.speed:    return '35% faster pace';
      case GameMode.marathon: return 'Level up every 25 lines';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SETTINGS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Persists and exposes all user-configurable settings.
///
/// Backed by [SharedPreferences] so settings survive app restarts.
class SettingsProvider extends ChangeNotifier {
  // ── Preference keys ────────────────────────────────────────────────────────
  static const _kMusic    = 'settings_music';
  static const _kVibrate  = 'settings_vibrate';
  static const _kMode     = 'settings_mode';
  static const _kTheme    = 'settings_theme';

  // ── Defaults ───────────────────────────────────────────────────────────────
  bool      _musicEnabled       = true;
  bool      _vibrateOnLevelUp   = true;
  GameMode  _gameMode           = GameMode.classic;
  ThemeMode _themeMode          = ThemeMode.dark;

  bool      get musicEnabled     => _musicEnabled;
  bool      get vibrateOnLevelUp => _vibrateOnLevelUp;
  GameMode  get gameMode         => _gameMode;
  ThemeMode get themeMode        => _themeMode;

  SettingsProvider() {
    _load();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _musicEnabled     = prefs.getBool(_kMusic)   ?? true;
    _vibrateOnLevelUp = prefs.getBool(_kVibrate) ?? true;
    _gameMode = GameMode.values[
      (prefs.getInt(_kMode) ?? 0).clamp(0, GameMode.values.length - 1)
    ];
    _themeMode = (prefs.getBool(_kTheme) ?? false)
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
  }

  // ── Setters ────────────────────────────────────────────────────────────────

  Future<void> setMusicEnabled(bool value) async {
    if (_musicEnabled == value) return;
    _musicEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusic, value);
  }

  Future<void> setVibrateOnLevelUp(bool value) async {
    if (_vibrateOnLevelUp == value) return;
    _vibrateOnLevelUp = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrate, value);
  }

  Future<void> setGameMode(GameMode mode) async {
    if (_gameMode == mode) return;
    _gameMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMode, mode.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTheme, mode == ThemeMode.light);
  }

  /// Convenience toggle for music.
  Future<void> toggleMusic() => setMusicEnabled(!_musicEnabled);

  /// Convenience toggle for theme.
  Future<void> toggleTheme() => setThemeMode(
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );
}
