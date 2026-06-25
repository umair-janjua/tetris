import 'package:flutter/material.dart';
import '../engine/game_engine.dart';
import '../theme/app_theme.dart';

/// [CustomPainter] that renders the entire 10×20 Tetris board.
///
/// Draws: background grid, locked cells (with neon glow), ghost piece
/// (semi-transparent outline), and the active falling piece (with bright glow).
class BoardPainter extends CustomPainter {
  final List<List<int>> board;
  final ActivePiece? currentPiece;
  final ActivePiece? ghostPiece;

  const BoardPainter({
    required this.board,
    this.currentPiece,
    this.ghostPiece,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width  / GameEngine.boardCols;
    final cellH = size.height / GameEngine.boardRows;

    _paintBackground(canvas, size, cellW, cellH);
    _paintLockedCells(canvas, cellW, cellH);
    _paintGhostPiece(canvas, cellW, cellH);
    _paintActivePiece(canvas, cellW, cellH);
    _paintBorder(canvas, size);
  }

  // ── Background & Grid ───────────────────────────────────────────────────────

  void _paintBackground(Canvas canvas, Size size, double cW, double cH) {
    // Deep-space background fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A1628),
    );

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.18)
      ..strokeWidth = 0.5;

    for (int c = 0; c <= GameEngine.boardCols; c++) {
      canvas.drawLine(
        Offset(c * cW, 0),
        Offset(c * cW, GameEngine.boardRows * cH),
        gridPaint,
      );
    }
    for (int r = 0; r <= GameEngine.boardRows; r++) {
      canvas.drawLine(
        Offset(0, r * cH),
        Offset(GameEngine.boardCols * cW, r * cH),
        gridPaint,
      );
    }
  }

  // ── Locked cells ────────────────────────────────────────────────────────────

  void _paintLockedCells(Canvas canvas, double cW, double cH) {
    for (int r = 0; r < GameEngine.boardRows; r++) {
      for (int c = 0; c < GameEngine.boardCols; c++) {
        final idx = board[r][c];
        if (idx != 0) {
          _drawCell(canvas, r, c, cW, cH, AppColors.tetrominoes[idx], glow: false);
        }
      }
    }
  }

  // ── Ghost piece ─────────────────────────────────────────────────────────────

  void _paintGhostPiece(Canvas canvas, double cW, double cH) {
    if (ghostPiece == null) return;
    final color = AppColors.tetrominoes[ghostPiece!.type.colorIndex];
    for (final cell in ghostPiece!.cells) {
      if (cell.row < 0 || cell.row >= GameEngine.boardRows) continue;
      _drawGhostCell(canvas, cell.row, cell.col, cW, cH, color);
    }
  }

  // ── Active piece ────────────────────────────────────────────────────────────

  void _paintActivePiece(Canvas canvas, double cW, double cH) {
    if (currentPiece == null) return;
    final color = AppColors.tetrominoes[currentPiece!.type.colorIndex];
    for (final cell in currentPiece!.cells) {
      if (cell.row < 0 || cell.row >= GameEngine.boardRows) continue;
      _drawCell(canvas, cell.row, cell.col, cW, cH, color, glow: true);
    }
  }

  // ── Board border ────────────────────────────────────────────────────────────

  void _paintBorder(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = AppColors.accent.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ── Cell drawing helpers ────────────────────────────────────────────────────

  void _drawCell(
    Canvas canvas,
    int row, int col,
    double cW, double cH,
    Color color, {
    required bool glow,
  }) {
    final x    = col * cW;
    final y    = row * cH;
    const pad  = 1.5;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad, y + pad, cW - pad * 2, cH - pad * 2),
      Radius.circular(cW * 0.12),
    );

    // Soft glow halo (active piece only)
    if (glow) {
      canvas.drawRRect(
        rect.inflate(cW * 0.18),
        Paint()
          ..color = color.withOpacity(0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cW * 0.55),
      );
    }

    // Base fill
    canvas.drawRRect(rect, Paint()..color = color);

    // Top-left shine highlight (3D bevel effect)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + pad, y + pad, (cW - pad * 2) * 0.62, (cH - pad * 2) * 0.36),
        Radius.circular(cW * 0.08),
      ),
      Paint()..color = Colors.white.withOpacity(0.28),
    );

    // Bottom shadow strip (depth illusion)
    final shadowH = (cH - pad * 2) * 0.14;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x + pad,
          y + cH - pad - shadowH,
          cW - pad * 2,
          shadowH,
        ),
        Radius.circular(cW * 0.06),
      ),
      Paint()..color = Colors.black.withOpacity(0.4),
    );
  }

  void _drawGhostCell(
    Canvas canvas, int row, int col, double cW, double cH, Color color) {
    final x   = col * cW;
    final y   = row * cH;
    const pad = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + pad, y + pad, cW - pad * 2, cH - pad * 2),
        Radius.circular(cW * 0.12),
      ),
      Paint()
        ..color = color.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.board         != board         ||
      old.currentPiece  != currentPiece  ||
      old.ghostPiece    != ghostPiece;
}
