import 'package:flutter/material.dart';
import '../engine/game_engine.dart';
import '../theme/app_theme.dart';

/// [CustomPainter] that renders the entire 12×20 Cubicles board.
///
/// Draws: futuristic cyber grid, matrix intersection dots, locked crystal cells,
/// holographic laser ghost piece, and glowing falling piece with corner brackets.
class BoardPainter extends CustomPainter {
  final List<List<int>> board;

  /// Version counter for [board]. The engine mutates the same list in place,
  /// so identity comparison can never detect a change — [shouldRepaint]
  /// compares this instead.
  final int boardVersion;

  final ActivePiece? currentPiece;
  final ActivePiece? ghostPiece;
  final bool isDark;

  const BoardPainter({
    required this.board,
    required this.boardVersion,
    this.currentPiece,
    this.ghostPiece,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / GameEngine.boardCols;
    final cellH = size.height / GameEngine.boardRows;

    _paintBackground(canvas, size, cellW, cellH);
    _paintGrid(canvas, size, cellW, cellH);
    _paintLockedCells(canvas, cellW, cellH);
    _paintGhostPiece(canvas, cellW, cellH);
    _paintActivePiece(canvas, cellW, cellH);
    _paintCyberFrame(canvas, size);
  }

  // ── Background & Cyber Grid ────────────────────────────────────────────────

  void _paintBackground(Canvas canvas, Size size, double cW, double cH) {
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF070C18), const Color(0xFF0C1428), const Color(0xFF080D1A)]
            : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
      ).createShader(bgRect);

    canvas.drawRect(bgRect, bgPaint);
  }

  void _paintGrid(Canvas canvas, Size size, double cW, double cH) {
    final gridColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.45)
        : const Color(0xFFCBD5E1).withValues(alpha: 0.6);

    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.6;

    // Vertical lines
    for (int c = 1; c < GameEngine.boardCols; c++) {
      final x = c * cW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    // Horizontal lines
    for (int r = 1; r < GameEngine.boardRows; r++) {
      final y = r * cH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Matrix intersection dots
    final dotPaint = Paint()
      ..color = (isDark ? AppColors.accent : const Color(0xFF64748B))
          .withValues(alpha: isDark ? 0.25 : 0.20);

    for (int r = 1; r < GameEngine.boardRows; r++) {
      for (int c = 1; c < GameEngine.boardCols; c++) {
        canvas.drawCircle(Offset(c * cW, r * cH), 1.0, dotPaint);
      }
    }
  }

  // ── Locked cells ───────────────────────────────────────────────────────────

  void _paintLockedCells(Canvas canvas, double cW, double cH) {
    for (int r = 0; r < GameEngine.boardRows; r++) {
      for (int c = 0; c < GameEngine.boardCols; c++) {
        final idx = board[r][c];
        if (idx != 0 && idx < AppColors.tetrominoes.length) {
          _drawCell(canvas, r, c, cW, cH, AppColors.tetrominoes[idx], glow: false);
        }
      }
    }
  }

  // ── Ghost piece (Holographic Laser Outline) ────────────────────────────────

  void _paintGhostPiece(Canvas canvas, double cW, double cH) {
    if (ghostPiece == null) return;
    final color = AppColors.tetrominoes[ghostPiece!.type.colorIndex];
    for (final cell in ghostPiece!.cells) {
      if (cell.row < 0 || cell.row >= GameEngine.boardRows) continue;
      _drawGhostCell(canvas, cell.row, cell.col, cW, cH, color);
    }
  }

  // ── Active piece ───────────────────────────────────────────────────────────

  void _paintActivePiece(Canvas canvas, double cW, double cH) {
    if (currentPiece == null) return;
    final color = AppColors.tetrominoes[currentPiece!.type.colorIndex];
    for (final cell in currentPiece!.cells) {
      if (cell.row < 0 || cell.row >= GameEngine.boardRows) continue;
      _drawCell(canvas, cell.row, cell.col, cW, cH, color, glow: true);
    }
  }

  // ── Cyber Frame & Corner Brackets ──────────────────────────────────────────

  void _paintCyberFrame(Canvas canvas, Size size) {
    final frameRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Glowing perimeter
    final borderPaint = Paint()
      ..color = (isDark ? AppColors.accent : const Color(0xFF0284C7))
          .withValues(alpha: isDark ? 0.45 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRect(frameRect, borderPaint);

    // Corner targeting brackets
    const bracketLen = 14.0;
    final bracketPaint = Paint()
      ..color = isDark ? AppColors.accent : const Color(0xFF0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.square;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(bracketLen, 0), bracketPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, bracketLen), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - bracketLen, 0), bracketPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, bracketLen), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(bracketLen, size.height), bracketPaint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - bracketLen), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - bracketLen, size.height), bracketPaint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - bracketLen), bracketPaint);
  }

  // ── Crystal Cell Drawing ───────────────────────────────────────────────────

  void _drawCell(
    Canvas canvas,
    int row, int col,
    double cW, double cH,
    Color color, {
    required bool glow,
  }) {
    final x = col * cW;
    final y = row * cH;
    const pad = 1.2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad, y + pad, cW - pad * 2, cH - pad * 2),
      Radius.circular(cW * 0.16),
    );

    // Dynamic neon aura glow
    if (glow) {
      canvas.drawRRect(
        rect.inflate(cW * 0.22),
        Paint()
          ..color = color.withValues(alpha: 0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cW * 0.65),
      );
    }

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
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + pad + 0.8, y + pad + 0.8, cW - (pad + 0.8) * 2, cH - (pad + 0.8) * 2),
        Radius.circular(cW * 0.12),
      ),
      innerBorder,
    );

    // 3. Specular Glare (Top Glass Highlight)
    final shineW = (cW - pad * 2) * 0.68;
    final shineH = (cH - pad * 2) * 0.32;
    final shineRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad + 2.0, y + pad + 1.5, shineW, shineH),
      Radius.circular(cW * 0.08),
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

    // 4. Subtle Center Jewel Inset
    final centerW = (cW - pad * 2) * 0.30;
    final centerH = (cH - pad * 2) * 0.30;
    final centerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        x + (cW - centerW) / 2,
        y + (cH - centerH) / 2,
        centerW,
        centerH,
      ),
      Radius.circular(cW * 0.06),
    );
    canvas.drawRRect(
      centerRRect,
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  void _drawGhostCell(
    Canvas canvas, int row, int col, double cW, double cH, Color color) {
    final x = col * cW;
    final y = row * cH;
    const pad = 1.8;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad, y + pad, cW - pad * 2, cH - pad * 2),
      Radius.circular(cW * 0.14),
    );

    // Soft laser projection background tint
    canvas.drawRRect(
      rect,
      Paint()..color = color.withValues(alpha: 0.08),
    );

    // Glowing holographic border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Center cross marker
    final centerDotPaint = Paint()..color = color.withValues(alpha: 0.40);
    canvas.drawCircle(Offset(x + cW / 2, y + cH / 2), 1.5, centerDotPaint);
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.boardVersion != boardVersion ||
      !_samePiece(old.currentPiece, currentPiece) ||
      !_samePiece(old.ghostPiece, ghostPiece) ||
      old.isDark != isDark;

  /// [ActivePiece] is immutable but has no value equality, so compare fields.
  static bool _samePiece(ActivePiece? a, ActivePiece? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.type == b.type &&
        a.row == b.row &&
        a.col == b.col &&
        a.rotation == b.rotation;
  }
}
