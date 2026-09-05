// ═══════════════════════════════════════════════════════════════════════════════
// TETROMINO TYPE
// ═══════════════════════════════════════════════════════════════════════════════

/// The 7 classic Tetromino piece types.
///
/// The [colorIndex] maps each type to its slot in [AppColors.tetrominoes] (1-7).
enum TetrominoType {
  I, O, T, S, Z, J, L;

  /// 1-based index into the tetrominoes color palette (0 is reserved for empty).
  int get colorIndex => index + 1;
}

/// Direction of a rotation request.
enum RotationDir { cw, ccw }

// ═══════════════════════════════════════════════════════════════════════════════
// TETROMINO SHAPES  (Super Rotation System)
// ═══════════════════════════════════════════════════════════════════════════════

/// Shape data for all 7 tetrominos across 4 rotations, in SRS layout.
///
/// J, L, S, T and Z rotate inside a 3×3 box; I inside a 4×4 box; O never moves.
/// Each rotation is a list of `[row, col]` cell offsets from the box origin.
/// Rotation order: 0 → R (90° CW) → 2 (180°) → L (270° CW).
///
/// Keeping the exact SRS layout matters: the wall-kick tables in [kicksFor]
/// are only correct for pieces defined in these boxes at these offsets.
class TetrominoData {
  TetrominoData._();

  static const Map<TetrominoType, List<List<List<int>>>> shapes = {

    // ── I ────────────────────────────────────────────────────────────────────
    //  0:  . . . .     R:  . . X .     2:  . . . .     L:  . X . .
    //      X X X X         . . X .         . . . .         . X . .
    //      . . . .         . . X .         X X X X         . X . .
    //      . . . .         . . X .         . . . .         . X . .
    TetrominoType.I: [
      [[1, 0], [1, 1], [1, 2], [1, 3]], // 0
      [[0, 2], [1, 2], [2, 2], [3, 2]], // R
      [[2, 0], [2, 1], [2, 2], [2, 3]], // 2
      [[0, 1], [1, 1], [2, 1], [3, 1]], // L
    ],

    // ── O ────────────────────────────────────────────────────────────────────
    //  All rotations identical:  . X X .
    //                            . X X .
    TetrominoType.O: [
      [[0, 1], [0, 2], [1, 1], [1, 2]],
      [[0, 1], [0, 2], [1, 1], [1, 2]],
      [[0, 1], [0, 2], [1, 1], [1, 2]],
      [[0, 1], [0, 2], [1, 1], [1, 2]],
    ],

    // ── T ────────────────────────────────────────────────────────────────────
    //  0:  . X .     R:  . X .     2:  . . .     L:  . X .
    //      X X X         . X X         X X X         X X .
    //      . . .         . X .         . X .         . X .
    TetrominoType.T: [
      [[0, 1], [1, 0], [1, 1], [1, 2]], // 0
      [[0, 1], [1, 1], [1, 2], [2, 1]], // R
      [[1, 0], [1, 1], [1, 2], [2, 1]], // 2
      [[0, 1], [1, 0], [1, 1], [2, 1]], // L
    ],

    // ── S ────────────────────────────────────────────────────────────────────
    //  0:  . X X     R:  . X .     2:  . . .     L:  X . .
    //      X X .         . X X         . X X         X X .
    //      . . .         . . X         X X .         . X .
    TetrominoType.S: [
      [[0, 1], [0, 2], [1, 0], [1, 1]], // 0
      [[0, 1], [1, 1], [1, 2], [2, 2]], // R
      [[1, 1], [1, 2], [2, 0], [2, 1]], // 2
      [[0, 0], [1, 0], [1, 1], [2, 1]], // L
    ],

    // ── Z ────────────────────────────────────────────────────────────────────
    //  0:  X X .     R:  . . X     2:  . . .     L:  . X .
    //      . X X         . X X         X X .         X X .
    //      . . .         . X .         . X X         X . .
    TetrominoType.Z: [
      [[0, 0], [0, 1], [1, 1], [1, 2]], // 0
      [[0, 2], [1, 1], [1, 2], [2, 1]], // R
      [[1, 0], [1, 1], [2, 1], [2, 2]], // 2
      [[0, 1], [1, 0], [1, 1], [2, 0]], // L
    ],

    // ── J ────────────────────────────────────────────────────────────────────
    //  0:  X . .     R:  . X X     2:  . . .     L:  . X .
    //      X X X         . X .         X X X         . X .
    //      . . .         . X .         . . X         X X .
    TetrominoType.J: [
      [[0, 0], [1, 0], [1, 1], [1, 2]], // 0
      [[0, 1], [0, 2], [1, 1], [2, 1]], // R
      [[1, 0], [1, 1], [1, 2], [2, 2]], // 2
      [[0, 1], [1, 1], [2, 0], [2, 1]], // L
    ],

    // ── L ────────────────────────────────────────────────────────────────────
    //  0:  . . X     R:  . X .     2:  . . .     L:  X X .
    //      X X X         . X .         X X X         . X .
    //      . . .         . X X         X . .         . X .
    TetrominoType.L: [
      [[0, 2], [1, 0], [1, 1], [1, 2]], // 0
      [[0, 1], [1, 1], [2, 1], [2, 2]], // R
      [[1, 0], [1, 1], [1, 2], [2, 0]], // 2
      [[0, 0], [0, 1], [1, 1], [2, 1]], // L
    ],
  };

  // ═════════════════════════════════════════════════════════════════════════
  // WALL KICK TABLES
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Offsets are stored as [dRow, dCol] in *board* coordinates, where dRow is
  // positive downwards. The published SRS tables use (x, y) with y positive
  // upwards, so every entry here is that table's (x, y) written as [-y, x].
  //
  // The map key encodes the transition as `from * 4 + to`.

  static const Map<int, List<List<int>>> _jlstzKicks = {
    0 * 4 + 1: [[0, 0], [0, -1], [-1, -1], [ 2, 0], [ 2, -1]], // 0 → R
    1 * 4 + 0: [[0, 0], [0,  1], [ 1,  1], [-2, 0], [-2,  1]], // R → 0
    1 * 4 + 2: [[0, 0], [0,  1], [ 1,  1], [-2, 0], [-2,  1]], // R → 2
    2 * 4 + 1: [[0, 0], [0, -1], [-1, -1], [ 2, 0], [ 2, -1]], // 2 → R
    2 * 4 + 3: [[0, 0], [0,  1], [-1,  1], [ 2, 0], [ 2,  1]], // 2 → L
    3 * 4 + 2: [[0, 0], [0, -1], [ 1, -1], [-2, 0], [-2, -1]], // L → 2
    3 * 4 + 0: [[0, 0], [0, -1], [ 1, -1], [-2, 0], [-2, -1]], // L → 0
    0 * 4 + 3: [[0, 0], [0,  1], [-1,  1], [ 2, 0], [ 2,  1]], // 0 → L
  };

  static const Map<int, List<List<int>>> _iKicks = {
    0 * 4 + 1: [[0, 0], [0, -2], [0,  1], [ 1, -2], [-2,  1]], // 0 → R
    1 * 4 + 0: [[0, 0], [0,  2], [0, -1], [-1,  2], [ 2, -1]], // R → 0
    1 * 4 + 2: [[0, 0], [0, -1], [0,  2], [-2, -1], [ 1,  2]], // R → 2
    2 * 4 + 1: [[0, 0], [0,  1], [0, -2], [ 2,  1], [-1, -2]], // 2 → R
    2 * 4 + 3: [[0, 0], [0,  2], [0, -1], [-1,  2], [ 2, -1]], // 2 → L
    3 * 4 + 2: [[0, 0], [0, -2], [0,  1], [ 1, -2], [-2,  1]], // L → 2
    3 * 4 + 0: [[0, 0], [0,  1], [0, -2], [ 2,  1], [-1, -2]], // L → 0
    0 * 4 + 3: [[0, 0], [0, -1], [0,  2], [-2, -1], [ 1,  2]], // 0 → L
  };

  /// Candidate `[dRow, dCol]` offsets to try, in order, when rotating [type]
  /// from rotation [from] to rotation [to].
  ///
  /// The first entry is always the no-kick case. O never kicks — it occupies
  /// the same cells in every rotation.
  static List<List<int>> kicksFor(TetrominoType type, int from, int to) {
    if (type == TetrominoType.O) return const [[0, 0]];
    final table = type == TetrominoType.I ? _iKicks : _jlstzKicks;
    return table[from * 4 + to] ?? const [[0, 0]];
  }
}
