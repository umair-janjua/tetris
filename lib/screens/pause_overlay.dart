import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// Animated pause overlay with resume, restart, and menu buttons.
class PauseOverlay extends StatefulWidget {
  const PauseOverlay({super.key});

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GameProvider>();
    final tc = ThemeColors.of(context);

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
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
                  color: tc.accent.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tc.accent.withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Pause Icon Badge ─────────────────────────────────────
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tc.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tc.accent.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tc.accent.withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.pause_rounded,
                      color: tc.accent,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Title ────────────────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                    ).createShader(bounds),
                    child: Text(
                      'PAUSED',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: Colors.white, letterSpacing: 4),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Score: ${p.score}  ·  Level ${p.level}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tc.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: tc.border),
                  const SizedBox(height: 20),

                  // ── Buttons ──────────────────────────────────────────────
                  // Resume
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.read<GameProvider>().resumeGame(),
                      child: const Text('RESUME'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Restart
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          context.read<GameProvider>().restartGame(),
                      child: const Text('RESTART'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Menu
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
