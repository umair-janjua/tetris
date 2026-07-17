import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/start_screen.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';

/// Root application widget.
///
/// Sets up the Provider tree with [AudioService] and [GameProvider] so both
/// are accessible anywhere in the widget tree and survive route transitions.
class TetrisApp extends StatelessWidget {
  const TetrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AudioService must be created first so GameProvider can reference it.
    return ChangeNotifierProvider(
      create: (_) => AudioService(),
      child: Builder(
        builder: (ctx) => ChangeNotifierProvider(
          create: (_) => GameProvider(audio: ctx.read<AudioService>()),
          child: MaterialApp(
            title: 'Tetris',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const StartScreen(),
          ),
        ),
      ),
    );
  }
}
