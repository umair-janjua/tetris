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
/// | Gesture       | Action      |
/// |---------------|-------------|
/// | Short tap     | Rotate CW   |
/// | Swipe ←/→    | Move        |
/// | Swipe ↓       | Soft drop   |
/// | Long press    | Hard drop   |
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Maintain 1:2 aspect ratio (10 cols : 20 rows).
        final cellSize = (constraints.maxWidth  / GameEngine.boardCols)
            .clamp(0.0, constraints.maxHeight / GameEngine.boardRows);
        final boardW = cellSize * GameEngine.boardCols;
        final boardH = cellSize * GameEngine.boardRows;

        return Center(
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
                builder: (_, provider, __) => Stack(
                  children: [
                    // ── Game board ────────────────────────────────────────
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size(boardW, boardH),
                        painter: BoardPainter(
                          board:        provider.board,
                          currentPiece: provider.currentPiece,
                          ghostPiece:   provider.ghostPiece,
                        ),
                      ),
                    ),

                    // ── Particle explosion on line clear ──────────────────
                    if (provider.clearedRows.isNotEmpty)
                      ParticleOverlay(
                        // New key forces re-creation on every distinct clear.
                        key: ValueKey(
                          '${provider.clearedRows.join(',')}'
                          '_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                        clearedRows: List<int>.from(provider.clearedRows),
                        cellSize:   cellSize,
                        boardWidth: boardW,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Gesture handlers ────────────────────────────────────────────────────────

  void _onTap() {
    final provider = context.read<GameProvider>();
    if (provider.status == GameStatus.playing) provider.rotateCW();
  }

  void _onLongPress() => context.read<GameProvider>().hardDrop();

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

  void _onPanEnd(DragEndDetails _) {
    _onPanCancel();
  }

  void _onPanCancel() {
    _isPanning = false;
    _accumH = _accumV = 0;
  }
}
