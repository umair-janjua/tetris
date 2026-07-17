import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Particle burst overlay shown when lines are cleared.
///
/// Spawns colorful particles at each cleared row and animates them outward
/// with gravity over 900 ms.
class ParticleOverlay extends StatefulWidget {
  final List<int> clearedRows;
  final double cellSize;
  final double boardWidth;

  const ParticleOverlay({
    super.key,
    required this.clearedRows,
    required this.cellSize,
    required this.boardWidth,
  });

  @override
  State<ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<ParticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = _generate();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  List<_Particle> _generate() {
    final rng = Random();
    final list = <_Particle>[];

    for (final row in widget.clearedRows) {
      final cy = row * widget.cellSize + widget.cellSize / 2;
      for (int i = 0; i < 24; i++) {
        final x   = rng.nextDouble() * widget.boardWidth;
        final idx = rng.nextInt(7) + 1; // 1-7 tetromino colors
        list.add(_Particle(
          x:     x,
          y:     cy,
          vx:    (rng.nextDouble() - 0.5) * 220,
          vy:    -(rng.nextDouble() * 230 + 50),
          color: AppColors.tetrominoes[idx],
          size:  rng.nextDouble() * 5 + 2.5,
          round: rng.nextBool(),
        ));
      }
    }
    return list;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(particles: _particles, t: _ctrl.value),
        ),
      );
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _Particle {
  final double x, y;   // origin
  final double vx, vy; // velocity
  final Color color;
  final double size;
  final bool round;    // circle vs square

  const _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.round,
  });

  /// Position at normalized time [t] (0→1) with simulated gravity.
  Offset posAt(double t) => Offset(
        x + vx * t,
        y + vy * t + 240 * t * t, // 240 px/s² gravity simulation
      );
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  const _ParticlePainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    for (final p in particles) {
      final pos     = p.posAt(t);
      final curSize = p.size * (1 - t * 0.45);
      final paint   = Paint()..color = p.color.withOpacity(opacity);

      if (p.round) {
        canvas.drawCircle(pos, curSize, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: pos, width: curSize * 2, height: curSize * 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
