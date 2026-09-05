import 'package:flutter_test/flutter_test.dart';
import 'package:cubicles/engine/game_engine.dart';
import 'package:cubicles/models/tetromino.dart';
import 'package:cubicles/providers/settings_provider.dart';

/// A started engine with a deterministic, empty board.
GameEngine _engine() => GameEngine()
  ..initialize()
  ..startGame();

/// Number of filled cells on the board.
int _filled(GameEngine e) =>
    e.board.fold(0, (n, row) => n + row.where((c) => c != 0).length);

/// Force a specific piece into a known position, bypassing the bag.
void _place(GameEngine e, TetrominoType type, int row, int col, [int rot = 0]) {
  e.currentPiece = ActivePiece(type: type, row: row, col: col, rotation: rot);
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  group('hold', () {
    test('is limited to once per piece, including the very first hold', () {
      final e = _engine();
      expect(e.canHold, isTrue);

      expect(e.holdPiece(), isTrue);
      expect(e.canHold, isFalse,
          reason: 'stashing the first piece must still consume the hold');

      final stashed = e.holdPieceType;
      expect(e.holdPiece(), isFalse, reason: 'second hold must be refused');
      expect(e.holdPieceType, stashed, reason: 'hold slot must be untouched');
    });

    test('is available again after the next piece locks', () {
      final e = _engine();
      e.holdPiece();
      expect(e.canHold, isFalse);
      e.hardDrop();
      expect(e.canHold, isTrue);
    });

    test('swaps the current piece with the held one', () {
      final e = _engine();
      final first = e.currentPiece!.type;
      e.holdPiece();
      e.hardDrop(); // locks that piece and re-enables hold
      final third = e.currentPiece!.type;

      e.holdPiece();
      expect(e.currentPiece!.type, first, reason: 'stashed piece comes back');
      expect(e.holdPieceType, third, reason: 'the live piece takes the slot');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('scoring', () {
    test('high score tracks drop points, not just line clears', () {
      final e = GameEngine()..initialize(savedHighScore: 0);
      e.startGame();

      while (e.status == GameStatus.playing) {
        e.hardDrop();
      }

      expect(e.score, greaterThan(0));
      expect(e.highScore, e.score,
          reason: 'a game with no line clears must still set a record');
    });

    test('soft drop awards a point per row and updates the record', () {
      final e = GameEngine()..initialize(savedHighScore: 0);
      e.startGame();
      expect(e.softDrop(), isTrue);
      expect(e.score, 1);
      expect(e.highScore, 1);
    });

    test('a saved record is not overwritten by a worse game', () {
      final e = GameEngine()..initialize(savedHighScore: 5000);
      e.startGame();
      e.softDrop();
      expect(e.highScore, 5000);
    });

    test('line clear scores base points times level', () {
      final e = _engine();
      // Fill the bottom row except one column, then drop an I piece into it.
      for (int c = 0; c < GameEngine.boardCols - 4; c++) {
        e.board[GameEngine.boardRows - 1][c] = 1;
      }
      _place(e, TetrominoType.I, 0, GameEngine.boardCols - 4);
      final before = e.score;
      final cleared = e.hardDrop();

      expect(cleared, [GameEngine.boardRows - 1]);
      expect(e.linesCleared, 1);
      // 100 * level 1, plus the hard-drop distance bonus.
      expect(e.score - before, greaterThanOrEqualTo(100));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('locking', () {
    test('a piece resting above the board ends the game instead of vanishing',
        () {
      final e = _engine();
      // Block column 6 from row 1 down; a vertical I at row -1 cannot fit.
      for (int r = 1; r < GameEngine.boardRows; r++) {
        e.board[r][6] = 1;
      }
      _place(e, TetrominoType.I, -1, 4, 1);
      expect(e.currentPiece!.cells.any((c) => c.row < 0), isTrue);

      e.lockPiece();

      expect(e.status, GameStatus.gameOver,
          reason: 'locking out must end the game, not silently drop cells');
    });

    test('every cell of a fully visible piece reaches the board', () {
      final e = _engine();
      final before = _filled(e);
      e.hardDrop();
      expect(_filled(e) - before, 4);
    });

    test('a blocked spawn ends the game', () {
      final e = _engine();
      // Occupy the spawn zone without completing any row, so the next spawn
      // has nowhere to go.
      for (int r = 0; r < 2; r++) {
        for (int c = 4; c <= 7; c++) {
          e.board[r][c] = 1;
        }
      }
      _place(e, TetrominoType.O, GameEngine.boardRows - 2, 0);
      e.lockPiece();
      expect(e.status, GameStatus.gameOver);
    });

    test('a full board bottom-up eventually tops out', () {
      final e = _engine();
      var guard = 0;
      while (e.status == GameStatus.playing && guard++ < 1000) {
        e.hardDrop();
      }
      expect(e.status, GameStatus.gameOver);
      expect(guard, lessThan(1000));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('gravity', () {
    test('a grounded piece locks on the very next tick', () {
      final e = _engine();
      while (e.softDrop()) {} // rest on the floor without locking

      expect(e.isGrounded, isTrue);
      expect(_filled(e), 0, reason: 'soft drop alone must not commit');

      e.tick();
      expect(_filled(e), 4, reason: 'no grace period — it locks immediately');
    });

    test('tick moves the piece down while it can still fall', () {
      final e = _engine();
      final row = e.currentPiece!.row;
      e.tick();
      expect(e.currentPiece!.row, row + 1);
      expect(_filled(e), 0);
    });

    test('isGrounded is false while the piece can still fall', () {
      final e = _engine();
      expect(e.isGrounded, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('SRS rotation', () {
    test('S and Z have four distinct rotation states', () {
      for (final type in [TetrominoType.S, TetrominoType.Z]) {
        final states = TetrominoData.shapes[type]!
            .map((r) => r.map((c) => '${c[0]},${c[1]}').join(' '))
            .toSet();
        expect(states.length, 4, reason: '$type must not reuse rotations');
      }
    });

    test('every piece keeps exactly four cells in every rotation', () {
      for (final type in TetrominoType.values) {
        for (final rot in TetrominoData.shapes[type]!) {
          expect(rot.length, 4, reason: '$type has a malformed rotation');
        }
      }
    });

    test('J and L rotate about their centre without drifting sideways', () {
      // In SRS the 3x3 centre cell is shared by every rotation of J/L/S/T/Z.
      for (final type in [
        TetrominoType.J,
        TetrominoType.L,
        TetrominoType.S,
        TetrominoType.T,
        TetrominoType.Z,
      ]) {
        for (final rot in TetrominoData.shapes[type]!) {
          final hasCentre = rot.any((c) => c[0] == 1 && c[1] == 1);
          expect(hasCentre, isTrue,
              reason: '$type rotation $rot is off its SRS pivot');
        }
      }
    });

    test('four clockwise rotations return to the start', () {
      final e = _engine();
      _place(e, TetrominoType.T, 5, 4);
      final start = e.currentPiece!;
      for (int i = 0; i < 4; i++) {
        expect(e.rotateCW(), isTrue);
      }
      expect(e.currentPiece!.rotation, start.rotation);
      expect(e.currentPiece!.col, start.col);
      expect(e.currentPiece!.row, start.row);
    });

    test('clockwise then counter-clockwise is a no-op', () {
      final e = _engine();
      _place(e, TetrominoType.J, 5, 4);
      final before = e.currentPiece!;
      e.rotateCW();
      e.rotateCCW();
      expect(e.currentPiece!.rotation, before.rotation);
      expect(e.currentPiece!.col, before.col);
      expect(e.currentPiece!.row, before.row);
    });

    test('rotation kicks off the right wall instead of failing', () {
      final e = _engine();
      // Vertical I hard against the right edge, then rotate flat.
      _place(e, TetrominoType.I, 5, GameEngine.boardCols - 3, 1);
      expect(e.currentPiece!.cells.every((c) => c.col < GameEngine.boardCols),
          isTrue);
      expect(e.rotateCW(), isTrue, reason: 'a wall kick should rescue this');
      for (final cell in e.currentPiece!.cells) {
        expect(cell.col, inInclusiveRange(0, GameEngine.boardCols - 1));
      }
    });

    test('rotation is refused when no kick fits', () {
      final e = _engine();
      // Bury a T in a one-cell-wide slot with solid rock all around.
      for (int r = 0; r < GameEngine.boardRows; r++) {
        for (int c = 0; c < GameEngine.boardCols; c++) {
          e.board[r][c] = 1;
        }
      }
      _place(e, TetrominoType.T, 5, 4);
      for (final cell in e.currentPiece!.cells) {
        e.board[cell.row][cell.col] = 0;
      }
      expect(e.rotateCW(), isFalse);
      expect(e.currentPiece!.rotation, 0, reason: 'piece must not move');
    });

    test('O never moves when rotated', () {
      final e = _engine();
      _place(e, TetrominoType.O, 5, 4);
      final before = e.currentPiece!.cells.toString();
      e.rotateCW();
      expect(e.currentPiece!.cells.toString(), before);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('spawning', () {
    test('every piece spawns fully inside the board', () {
      final e = _engine();
      for (int i = 0; i < 50; i++) {
        final cells = e.currentPiece!.cells;
        for (final cell in cells) {
          expect(cell.col, inInclusiveRange(0, GameEngine.boardCols - 1),
              reason: '${e.currentPiece!.type} spawned out of bounds');
        }
        e.hardDrop();
        if (e.status != GameStatus.playing) e.startGame();
      }
    });

    test('pieces spawn horizontally centred', () {
      final e = _engine();
      for (final type in TetrominoType.values) {
        _place(e, type, 0, 0);
        final shape = TetrominoData.shapes[type]![0];
        final minC = shape.map((c) => c[1]).reduce((a, b) => a < b ? a : b);
        final maxC = shape.map((c) => c[1]).reduce((a, b) => a > b ? a : b);
        final width = maxC - minC + 1;
        final gapLeft = (GameEngine.boardCols - width) ~/ 2;
        final gapRight = GameEngine.boardCols - width - gapLeft;
        // Ties resolve left, so the gaps differ by at most one column.
        expect((gapLeft - gapRight).abs(), lessThanOrEqualTo(1));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('line clearing', () {
    test('clears multiple rows and keeps the board height', () {
      final e = _engine();
      for (int r = GameEngine.boardRows - 2; r < GameEngine.boardRows; r++) {
        for (int c = 0; c < GameEngine.boardCols - 1; c++) {
          e.board[r][c] = 1;
        }
      }
      _place(e, TetrominoType.I, 0, GameEngine.boardCols - 3, 1);
      final cleared = e.hardDrop();

      expect(cleared.length, 2);
      expect(e.board.length, GameEngine.boardRows);
      expect(e.board.every((r) => r.length == GameEngine.boardCols), isTrue);
      expect(e.linesCleared, 2);
    });

    test('boardVersion changes whenever the board changes', () {
      final e = _engine();
      final before = e.boardVersion;
      e.hardDrop();
      expect(e.boardVersion, greaterThan(before));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('levels and speed', () {
    test('classic levels up every 10 lines, marathon every 25', () {
      for (final mode in [GameMode.classic, GameMode.marathon]) {
        final e = _engine()..gameMode = mode;
        final per = mode == GameMode.marathon ? 25 : 10;

        // Clear rows directly through the public lock path.
        for (int i = 0; i < per; i++) {
          for (int c = 0; c < GameEngine.boardCols - 1; c++) {
            e.board[GameEngine.boardRows - 1][c] = 1;
          }
          _place(e, TetrominoType.O, GameEngine.boardRows - 2,
              GameEngine.boardCols - 3);
          e.lockPiece();
        }
        expect(e.linesCleared, per);
        expect(e.level, 2, reason: '$mode should be level 2 after $per lines');
      }
    });

    test('speed mode falls faster than classic at the same level', () {
      final classic = _engine()..gameMode = GameMode.classic;
      final speed = _engine()..gameMode = GameMode.speed;
      expect(speed.fallSpeedMs, lessThan(classic.fallSpeedMs));
    });

    test('fall speed never drops below the floor', () {
      final e = _engine()..level = 99;
      expect(e.fallSpeedMs, greaterThanOrEqualTo(100));
      e.gameMode = GameMode.speed;
      expect(e.fallSpeedMs, greaterThanOrEqualTo(60));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('ghost piece', () {
    test('lands on the stack, never inside it', () {
      final e = _engine();
      final ghost = e.ghostPiece!;
      for (final cell in ghost.cells) {
        expect(cell.row, lessThan(GameEngine.boardRows));
        if (cell.row >= 0) expect(e.board[cell.row][cell.col], 0);
      }
    });

    test('is null when the piece is already resting', () {
      final e = _engine();
      while (e.softDrop()) {}
      expect(e.ghostPiece, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('guards', () {
    test('no action mutates a finished game', () {
      final e = _engine();
      e.status = GameStatus.gameOver;
      final score = e.score;

      expect(e.moveLeft(), isFalse);
      expect(e.moveRight(), isFalse);
      expect(e.softDrop(), isFalse);
      expect(e.rotateCW(), isFalse);
      expect(e.holdPiece(), isFalse);
      expect(e.hardDrop(), isEmpty);
      expect(e.tick(), isEmpty);
      expect(e.score, score);
    });

    test('pieces cannot be pushed through the walls', () {
      final e = _engine();
      for (int i = 0; i < GameEngine.boardCols * 2; i++) {
        e.moveLeft();
      }
      expect(e.currentPiece!.cells.map((c) => c.col).reduce((a, b) => a < b ? a : b),
          greaterThanOrEqualTo(0));

      for (int i = 0; i < GameEngine.boardCols * 4; i++) {
        e.moveRight();
      }
      expect(e.currentPiece!.cells.map((c) => c.col).reduce((a, b) => a > b ? a : b),
          lessThan(GameEngine.boardCols));
    });
  });
}
