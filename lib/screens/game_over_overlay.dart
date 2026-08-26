import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// Animated game-over overlay with final stats, play-again, and menu buttons.
///
/// Animates in with a scale + fade entrance.
class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({super.key});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p  = context.watch<GameProvider>();
    final tc = ThemeColors.of(context);

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withOpacity(0.82),
          alignment: Alignment.center,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppColors.error.withOpacity(0.45), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.12),
                    blurRadius: 40, spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Title ───────────────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
                    ).createShader(bounds),
                    child: Text(
                      'GAME OVER',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: Colors.white, letterSpacing: 3),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Level reached
                  Text(
                    'Level ${p.level} reached',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tc.textMuted,
                        ),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: tc.border),
                  const SizedBox(height: 16),

                  // ── Stats ───────────────────────────────────────────────
                  _Stat(label: 'SCORE',  value: '${p.score}',  tc: tc),
                  const SizedBox(height: 10),
                  _Stat(
                    label: 'BEST',
                    value: '${p.highScore}',
                    isGold: true,
                    tc: tc,
                  ),
                  const SizedBox(height: 10),
                  _Stat(label: 'LINES',  value: '${p.linesCleared}', tc: tc),

                  const SizedBox(height: 28),

                  // ── Buttons ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.read<GameProvider>().restartGame(),
                      child: const Text('PLAY AGAIN'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('MENU'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool isGold;
  final ThemeColors tc;
  const _Stat({required this.label, required this.value, required this.tc, this.isGold = false});

  @override
  Widget build(BuildContext context) {
    final color = isGold ? AppColors.warning : tc.textPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isGold ? AppColors.warning : tc.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color, fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}
