import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// Full-screen semi-transparent overlay shown when the game is paused.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.78),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pause icon
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.accent.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.pause_rounded,
                  color: AppColors.accent, size: 34),
            ),

            const SizedBox(height: 22),

            Text(
              'PAUSED',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    letterSpacing: 6, color: AppColors.textPrimary),
            ),

            const SizedBox(height: 48),

            // Resume
            _Btn(
              label: 'RESUME',
              primary: true,
              onTap: () => context.read<GameProvider>().resumeGame(),
            ),
            const SizedBox(height: 10),

            // Restart
            _Btn(
              label: 'RESTART',
              onTap: () => context.read<GameProvider>().restartGame(),
            ),
            const SizedBox(height: 10),

            // Menu
            _Btn(
              label: 'MENU',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _Btn({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: primary
          ? ElevatedButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}
