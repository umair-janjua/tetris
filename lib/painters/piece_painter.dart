import 'package:flutter/material.dart';
import '../models/tetromino.dart';
import '../theme/app_theme.dart';

/// [CustomPainter] for the Next-piece and Hold-piece preview panels.
///
/// Renders a single tetromino piece at rotation 0, auto-scaled and centered
/// within the canvas, with neon glow and 3D bevel.
class PiecePainter extends CustomPainter {
  final TetrominoType? pieceType;

  const PiecePainter({this.pieceType});

  @override
  void paint(Canvas canvas, Size size) {
    if (pieceType == null) return;

    final cells = TetrominoData.shapes[pieceType!]![0]; // Always show at 0°

    // ── Compute tight bounding box ────────────────────────────────────────────
    int minR = cells.map((c) => c[0]).reduce((a, b) => a < b ? a : b);
    int maxR = cells.map((c) => c[0]).reduce((a, b) => a > b ? a : b);
    int minC = cells.map((c) => c[1]).reduce((a, b) => a < b ? a : b);
    int maxC = cells.map((c) => c[1]).reduce((a, b) => a > b ? a : b);

    final pieceRows = (maxR - minR + 1).toDouble();
    final pieceCols = (maxC - minC + 1).toDouble();

    // ── Cell size that fills the canvas with padding ──────────────────────────
    const pad      = 10.0;
    final cellSize = ((size.width - pad * 2) / pieceCols)
        .clamp(0.0, (size.height - pad * 2) / pieceRows);

    // ── Center offset ─────────────────────────────────────────────────────────
    final ox = (size.width  - pieceCols * cellSize) / 2;
    final oy = (size.height - pieceRows * cellSize) / 2;

    final color = AppColors.tetrominoes[pieceType!.colorIndex];

    for (final cell in cells) {
      final c = cell[1] - minC;
      final r = cell[0] - minR;
      _drawCell(canvas, r, c, cellSize, ox, oy, color);
    }
  }

  void _drawCell(
    Canvas canvas, int row, int col, double cs,
    double ox, double oy, Color color,
  ) {
    final x = ox + col * cs;
    final y = oy + row * cs;
    const pad = 1.2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad, y + pad, cs - pad * 2, cs - pad * 2),
      Radius.circular(cs * 0.16),
    );

    // Neon glow
    canvas.drawRRect(
      rect.inflate(cs * 0.18),
      Paint()
        ..color = color.withValues(alpha: 0.26)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.50),
    );

    // 1. Crystal Gradient Base Fill
    final cellRect = rect.outerRect;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(color, Colors.white, 0.32)!,
        color,
        Color.lerp(color, Colors.black, 0.38)!,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(rect, Paint()..shader = gradient.createShader(cellRect));

    // 2. High-Tech Inner Glow Rim
    final innerBorder = Paint()
      ..color = Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + pad + 0.6, y + pad + 0.6, cs - (pad + 0.6) * 2, cs - (pad + 0.6) * 2),
        Radius.circular(cs * 0.12),
      ),
      innerBorder,
    );

    // 3. Specular Glare (Top Glass Highlight)
    final shineW = (cs - pad * 2) * 0.68;
    final shineH = (cs - pad * 2) * 0.32;
    final shineRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad + 1.5, y + pad + 1.2, shineW, shineH),
      Radius.circular(cs * 0.08),
    );
    canvas.drawRRect(
      shineRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(shineRRect.outerRect),
    );
  }

  @override
  bool shouldRepaint(PiecePainter old) => old.pieceType != pieceType;
}
