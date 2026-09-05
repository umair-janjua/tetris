import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/start_screen.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';

/// Root application widget.
///
/// Sets up the Provider tree:
///   [SettingsProvider] → [AudioService] → [GameProvider]
///
/// [SettingsProvider] must be outermost so [AudioService] and [GameProvider]
/// can read settings at construction time.
class CubiclesApp extends StatelessWidget {
  const CubiclesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: Builder(
        builder: (settingsCtx) => ChangeNotifierProvider(
          create: (_) => AudioService(
            settings: settingsCtx.read<SettingsProvider>(),
          ),
          child: Builder(
            builder: (audioCtx) => ChangeNotifierProvider(
              create: (_) => GameProvider(
                audio: audioCtx.read<AudioService>(),
                settings: audioCtx.read<SettingsProvider>(),
              ),
              child: Consumer<SettingsProvider>(
                builder: (_, settings, _) => MaterialApp(
                  title: 'Cubicles',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: settings.themeMode,
                  home: const StartScreen(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
