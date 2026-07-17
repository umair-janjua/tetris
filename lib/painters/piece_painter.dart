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
    final x    = ox + col * cs;
    final y    = oy + row * cs;
    const pad  = 1.5;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad, y + pad, cs - pad * 2, cs - pad * 2),
      Radius.circular(cs * 0.15),
    );

    // Glow
    canvas.drawRRect(
      rect.inflate(cs * 0.14),
      Paint()
        ..color = color.withOpacity(0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.45),
    );

    // Fill
    canvas.drawRRect(rect, Paint()..color = color);

    // Shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + pad, y + pad, (cs - pad * 2) * 0.60, (cs - pad * 2) * 0.34),
        Radius.circular(cs * 0.1),
      ),
      Paint()..color = Colors.white.withOpacity(0.30),
    );
  }

  @override
  bool shouldRepaint(PiecePainter old) => old.pieceType != pieceType;
}
