import 'dart:math';
import '../models/tetromino.dart';
import '../providers/settings_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GAME STATUS
// ═══════════════════════════════════════════════════════════════════════════════

/// All possible states the Cubicles game can be in.
enum GameStatus {
  idle,     // Not yet started; showing start screen
  playing,  // Active gameplay
  paused,   // Player paused the game
  gameOver, // Piece blocked at spawn; game ended
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVE PIECE
// ═══════════════════════════════════════════════════════════════════════════════

/// The currently falling tetromino, including its board position and rotation.
class ActivePiece {
  final TetrominoType type;

  /// Row of the bounding-box origin (may be negative – cells above the board).
  final int row;

  /// Column of the bounding-box origin.
  final int col;

  /// Current rotation index (0–3).
  final int rotation;

  const ActivePiece({
    required this.type,
    required this.row,
    required this.col,
    this.rotation = 0,
  });

  /// Absolute board coordinates occupied by this piece.
  /// Records with row < 0 are above the visible board (valid, not rendered).
  List<({int row, int col})> get cells {
    final shape = TetrominoData.shapes[type]![rotation];
    return shape
        .map((c) => (row: row + c[0], col: col + c[1]))
        .toList();
  }

  /// Returns a copy with optional field overrides.
  ActivePiece copyWith({int? row, int? col, int? rotation}) => ActivePiece(
        type: type,
        row: row ?? this.row,
        col: col ?? this.col,
        rotation: rotation ?? this.rotation,
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BAG-7 RANDOMIZER
// ═══════════════════════════════════════════════════════════════════════════════

/// Standard "Bag-7" randomizer: shuffles all 7 pieces into a bag and
/// dispenses them one by one, reshuffling when the bag empties.
/// Guarantees at most 12 pieces between any two identical pieces.
class _Bag7 {
  final Random _rng = Random();
  final List<TetrominoType> _bag = [];

  TetrominoType next() {
    if (_bag.isEmpty) {
      _bag.addAll(TetrominoType.values);
      _bag.shuffle(_rng);
    }
    return _bag.removeLast();
  }

  void reset() => _bag.clear();
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME ENGINE  (pure Dart – no Flutter dependencies)
// ═══════════════════════════════════════════════════════════════════════════════

/// Core Cubicles game logic.
///
/// Manages board state, piece movement/rotation, line clearing,
/// scoring, level progression, and the hold/next-piece system.
class GameEngine {
  // ── Board Dimensions ───────────────────────────────────────────────────────
  static const int boardRows = 20;
  static const int boardCols = 12;

  /// Horizontal spawn position: centers the 4-wide bounding box in a 12-col board.
  static const int _spawnCol = 4;

  // ── Board State ────────────────────────────────────────────────────────────

  /// 20×12 grid. 0 = empty, 1–7 = locked tetromino color index.
  late List<List<int>> board;

  ActivePiece? currentPiece;
  TetrominoType? nextPieceType;
  TetrominoType? holdPieceType;

  /// False after the player uses hold for the current piece (resets on lock).
  bool canHold = true;

  // ── Scoring & Level ────────────────────────────────────────────────────────
  int score        = 0;
  int level        = 1;
  int linesCleared = 0;
  int highScore    = 0;

  GameStatus status = GameStatus.idle;

  /// The active game mode — affects fall speed and level-up threshold.
  GameMode gameMode = GameMode.classic;

  final _Bag7 _bag = _Bag7();

  // ── Initialization ─────────────────────────────────────────────────────────

  void initialize({int savedHighScore = 0}) {
    highScore = savedHighScore;
    _resetState();
  }

  void _resetState() {
    board = List.generate(boardRows, (_) => List.filled(boardCols, 0));
    currentPiece  = null;
    nextPieceType = null;
    holdPieceType = null;
    canHold       = true;
    score         = 0;
    level         = 1;
    linesCleared  = 0;
    _bag.reset();
    status = GameStatus.idle;
  }

  /// Start a fresh game.
  void startGame() {
    _resetState();
    status        = GameStatus.playing;
    nextPieceType = _bag.next();
    _spawnPiece();
  }

  // ── Piece Spawning ─────────────────────────────────────────────────────────

  void _spawnPiece() {
    final type = nextPieceType ?? _bag.next();
    nextPieceType = _bag.next();
    canHold = true;

    // Compute spawn row so the topmost visible cells appear at board row 0.
    final shape  = TetrominoData.shapes[type]![0];
    final minRow = shape.map((c) => c[0]).reduce(min);
    final spawnRow = -minRow; // For I: -1; for all others: 0

    currentPiece = ActivePiece(type: type, row: spawnRow, col: _spawnCol);

    // Game over when the spawn position is already blocked.
    if (!_isValid(currentPiece!)) {
      status = GameStatus.gameOver;
      currentPiece = null;
    }
  }

  // ── Player Movement ────────────────────────────────────────────────────────

  /// Shift the piece one column to the left.
  bool moveLeft() {
    if (!_canAct) return false;
    return _tryApply(currentPiece!.copyWith(col: currentPiece!.col - 1));
  }

  /// Shift the piece one column to the right.
  bool moveRight() {
    if (!_canAct) return false;
    return _tryApply(currentPiece!.copyWith(col: currentPiece!.col + 1));
  }

  /// Drop the piece one row (soft drop). Awards 1 bonus point per row.
  /// Returns false when the piece cannot move further down.
  bool softDrop() {
    if (!_canAct) return false;
    final moved = currentPiece!.copyWith(row: currentPiece!.row + 1);
    if (_isValid(moved)) {
      currentPiece = moved;
      score += 1;
      return true;
    }
    return false;
  }

  /// Instantly drop the piece to the lowest valid row and lock it.
  /// Awards 2 bonus points per row dropped.
  /// Returns the indices of any rows that were cleared.
  List<int> hardDrop() {
    if (!_canAct) return [];
    final gr       = _computeGhostRow();
    final distance = gr - currentPiece!.row;
    score += distance * 2;
    currentPiece = currentPiece!.copyWith(row: gr);
    return _lockPiece();
  }

  // ── Rotation ───────────────────────────────────────────────────────────────

  /// Rotate the current piece 90° clockwise with simplified wall-kick fallback.
  void rotateCW() {
    if (!_canAct) return;
    final newRot = (currentPiece!.rotation + 1) % 4;
    final rotated = currentPiece!.copyWith(rotation: newRot);

    // Plain rotation
    if (_isValid(rotated)) { currentPiece = rotated; return; }

    // Horizontal wall kicks (±1, ±2 columns)
    for (final dx in [-1, 1, -2, 2]) {
      final kicked = rotated.copyWith(col: rotated.col + dx);
      if (_isValid(kicked)) { currentPiece = kicked; return; }
    }

    // Floor kick: shift up by 1 row (helps I piece near bottom)
    final floorKick = rotated.copyWith(row: rotated.row - 1);
    if (_isValid(floorKick)) { currentPiece = floorKick; }

    // If all kicks fail, ignore the rotation request.
  }

  // ── Hold System ────────────────────────────────────────────────────────────

  /// Swap the current piece with the held piece (or stash it if empty).
  /// Limited to once per piece placement.
  void holdPiece() {
    if (!_canAct || !canHold) return;
    canHold = false;

    final current = currentPiece!.type;

    if (holdPieceType == null) {
      holdPieceType = current;
      _spawnPiece();
    } else {
      final held = holdPieceType!;
      holdPieceType = current;

      final shape  = TetrominoData.shapes[held]![0];
      final minRow = shape.map((c) => c[0]).reduce(min);
      currentPiece = ActivePiece(type: held, row: -minRow, col: _spawnCol);

      if (!_isValid(currentPiece!)) {
        status = GameStatus.gameOver;
        currentPiece = null;
      }
    }
  }

  // ── Game Tick (driven by provider timer) ───────────────────────────────────

  /// Advance the game one tick: drop the piece 1 row, or lock it if blocked.
  /// Returns cleared row indices (empty list when nothing was cleared).
  List<int> tick() {
    if (status != GameStatus.playing || currentPiece == null) return [];
    final moved = currentPiece!.copyWith(row: currentPiece!.row + 1);
    if (_isValid(moved)) { currentPiece = moved; return []; }
    return _lockPiece();
  }

  // ── Piece Locking & Line Clearing ──────────────────────────────────────────

  List<int> _lockPiece() {
    if (currentPiece == null) return [];

    // Commit all visible cells to the board.
    for (final cell in currentPiece!.cells) {
      if (cell.row >= 0 && cell.row < boardRows &&
          cell.col >= 0 && cell.col < boardCols) {
        board[cell.row][cell.col] = currentPiece!.type.colorIndex;
      }
    }
    currentPiece = null;

    final cleared = _clearLines();
    _spawnPiece();
    return cleared;
  }

  /// Detect and remove full rows. Returns the cleared row indices.
  List<int> _clearLines() {
    final fullRows = <int>[];
    for (int r = 0; r < boardRows; r++) {
      if (board[r].every((cell) => cell != 0)) fullRows.add(r);
    }
    if (fullRows.isEmpty) return [];

    // Remove rows top-to-bottom (reversed indices to keep positions valid).
    for (final r in fullRows.reversed) {
      board.removeAt(r);
    }
    // Prepend empty rows to keep total at 20.
    for (int i = 0; i < fullRows.length; i++) {
      board.insert(0, List.filled(boardCols, 0));
    }

    _applyScore(fullRows.length);
    return fullRows;
  }

  void _applyScore(int lineCount) {
    // Base scores per user spec, multiplied by current level.
    const basePoints = [0, 100, 300, 500, 800];
    score += (lineCount <= 4 ? basePoints[lineCount] : 800) * level;

    linesCleared += lineCount;

    // Marathon mode levels up every 25 lines; all other modes every 10.
    final linesPerLevel = gameMode == GameMode.marathon ? 25 : 10;
    level = (linesCleared ~/ linesPerLevel) + 1;

    if (score > highScore) highScore = score;
  }

  // ── Ghost Piece ────────────────────────────────────────────────────────────

  int _computeGhostRow() {
    if (currentPiece == null) return 0;
    int row = currentPiece!.row;
    while (_isValid(currentPiece!.copyWith(row: row + 1))) {
      row++;
    }
    return row;
  }

  /// Returns the ghost piece at the lowest valid landing row.
  /// Returns null if the ghost would overlap the current piece position.
  ActivePiece? get ghostPiece {
    if (currentPiece == null) return null;
    final gr = _computeGhostRow();
    if (gr == currentPiece!.row) return null;
    return currentPiece!.copyWith(row: gr);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _canAct => status == GameStatus.playing && currentPiece != null;

  /// Returns true when [piece] is fully within the board and has no overlaps.
  bool _isValid(ActivePiece piece) {
    for (final cell in piece.cells) {
      if (cell.col < 0 || cell.col >= boardCols) return false;
      if (cell.row >= boardRows) return false;
      // Cells above row 0 are always valid (piece entering from above).
      if (cell.row >= 0 && board[cell.row][cell.col] != 0) return false;
    }
    return true;
  }

  bool _tryApply(ActivePiece candidate) {
    if (_isValid(candidate)) { currentPiece = candidate; return true; }
    return false;
  }

  // ── Speed Schedule ─────────────────────────────────────────────────────────

  /// Fall interval in milliseconds. Decreases with level, min 100 ms (level 9+).
  ///
  /// Classic/Marathon: Level 1 → 900 ms, Level 2 → 800 ms, …, Level 9+ → 100 ms.
  /// Speed: 35% faster at each level (multiply classic speed by 0.65).
  int get fallSpeedMs {
    final base = max(100, 900 - (level - 1) * 100);
    if (gameMode == GameMode.speed) {
      return max(60, (base * 0.65).round());
    }
    return base;
  }

  // ── Pause / Resume ─────────────────────────────────────────────────────────

  void pause()  { if (status == GameStatus.playing) status = GameStatus.paused; }
  void resume() { if (status == GameStatus.paused)  status = GameStatus.playing; }
}
