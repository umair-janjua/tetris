import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/game_engine.dart';
import '../painters/board_painter.dart';
import '../providers/game_provider.dart';
import 'particle_overlay.dart';

/// The interactive game board widget.
///
/// Wraps [BoardPainter] and [ParticleOverlay] inside a [GestureDetector]
/// that maps touch gestures to game actions:
///
/// | Gesture        | Action      |
/// |----------------|-------------|
/// | Short tap      | Rotate CW   |
/// | Swipe ←/→      | Move        |
/// | Swipe ↓        | Soft drop   |
/// | Fast flick ↓   | Hard drop   |
/// | Long press     | Hard drop   |
class GameBoardWidget extends StatefulWidget {
  const GameBoardWidget({super.key});

  @override
  State<GameBoardWidget> createState() => _GameBoardWidgetState();
}

class _GameBoardWidgetState extends State<GameBoardWidget> {
  // Accumulated drag for step-based movement (one move per cell width)
  double _accumH = 0;
  double _accumV = 0;
  bool   _isPanning = false;
  Offset _panStart  = Offset.zero;

  // Pixels required to register one step of movement.
  static const double _stepPx = 18.0;

  /// Downward flick speed (px/s) that triggers a hard drop on release.
  ///
  /// Deliberately high: a normal soft-drop swipe can release at over
  /// 1000 px/s, and having those slam the piece down made the controls feel
  /// unpredictable. Only a sharp flick should hard drop.
  static const double _flickVelocity = 2200.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Preserve the board's 12:20 aspect ratio inside the available space.
        final cellSize = (constraints.maxWidth  / GameEngine.boardCols)
            .clamp(0.0, constraints.maxHeight / GameEngine.boardRows);
        final boardW = cellSize * GameEngine.boardCols;
        final boardH = cellSize * GameEngine.boardRows;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF0EA5E9).withValues(alpha: 0.16)
                      : const Color(0xFF0284C7).withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: boardW,
              height: boardH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                onLongPress: _onLongPress,
                onPanCancel: _onPanCancel,
                onPanStart:  _onPanStart,
                onPanUpdate: (d) => _onPanUpdate(d, cellSize),
                onPanEnd:    _onPanEnd,
                child: Consumer<GameProvider>(
                  builder: (_, provider, _) => Stack(
                    children: [
                      // ── Game board ────────────────────────────────────────
                      RepaintBoundary(
                        child: CustomPaint(
                          size: Size(boardW, boardH),
                          painter: BoardPainter(
                            board:        provider.board,
                            boardVersion: provider.boardVersion,
                            currentPiece: provider.currentPiece,
                            ghostPiece:   provider.ghostPiece,
                            isDark:       isDark,
                          ),
                        ),
                      ),

                      // ── Particle explosion on line clear ──────────────────
                      if (provider.clearedRows.isNotEmpty)
                        ParticleOverlay(
                          // Keyed by the burst id so the overlay is created
                          // once per clear. Keying on a timestamp would rebuild
                          // it on every notify and restart the animation.
                          key: ValueKey(provider.clearId),
                          clearedRows: List<int>.from(provider.clearedRows),
                          cellSize:   cellSize,
                          boardWidth: boardW,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Gesture handlers ────────────────────────────────────────────────────────

  bool get _isPlaying =>
      context.read<GameProvider>().status == GameStatus.playing;

  void _onTap() {
    if (_isPlaying) context.read<GameProvider>().rotateCW();
  }

  void _onLongPress() {
    if (_isPlaying) context.read<GameProvider>().hardDrop();
  }

  void _onPanStart(DragStartDetails d) {
    _isPanning = false;
    _panStart  = d.localPosition;
    _accumH = _accumV = 0;
  }

  void _onPanUpdate(DragUpdateDetails d, double cellSize) {
    // Classify as a pan only after the pointer moves > 6 px from the start.
    if ((d.localPosition - _panStart).distance > 6) _isPanning = true;
    if (!_isPanning) return;

    final provider = context.read<GameProvider>();
    if (provider.status != GameStatus.playing) return;

    final dx = d.delta.dx;
    final dy = d.delta.dy;

    if (dx.abs() >= dy.abs()) {
      // Horizontal movement
      _accumH += dx;
      if (_accumH >=  _stepPx) { _accumH = 0; provider.moveRight(); }
      if (_accumH <= -_stepPx) { _accumH = 0; provider.moveLeft();  }
    } else if (dy > 0) {
      // Soft drop (downward only)
      _accumV += dy;
      if (_accumV >= _stepPx) { _accumV = 0; provider.softDrop(); }
    }
  }

  void _onPanEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond;
    final wasPanning = _isPanning;
    _onPanCancel();

    // A fast downward flick hard-drops, so players are not stuck with the
    // slower long-press when they want to slam a piece down.
    if (wasPanning &&
        velocity.dy > _flickVelocity &&
        velocity.dy.abs() > velocity.dx.abs() &&
        _isPlaying) {
      context.read<GameProvider>().hardDrop();
    }
  }

  void _onPanCancel() {
    _isPanning = false;
    _accumH = _accumV = 0;
  }
}
