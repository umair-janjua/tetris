import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/game_engine.dart';
import '../models/tetromino.dart';
import '../services/audio_service.dart';

/// Sits between [GameEngine] and the UI.
///
/// Responsibilities:
/// - Owns and drives the game-loop [Timer].
/// - Persists / loads the high score via [SharedPreferences].
/// - Exposes game state to the widget tree and calls [notifyListeners].
/// - Fires audio events via [AudioService] at every meaningful game moment.
class GameProvider extends ChangeNotifier {
  final GameEngine   _engine = GameEngine();
  final AudioService _audio;

  Timer? _timer;

  /// Tracks last known fall speed so the timer is restarted when level changes.
  int _lastFallSpeedMs = 0;

  /// Tracks the previous level to detect level-up events.
  int _lastLevel = 1;

  /// Rows cleared on the most recent lock (used to trigger particle animation).
  List<int> _clearedRows = [];

  /// Guard against notifying after dispose.
  bool _disposed = false;

  GameProvider({required AudioService audio}) : _audio = audio {
    _loadHighScore();
  }

  // ── Getters (mirror GameEngine) ────────────────────────────────────────────
  List<List<int>> get board         => _engine.board;
  ActivePiece?    get currentPiece  => _engine.currentPiece;
  ActivePiece?    get ghostPiece    => _engine.ghostPiece;
  TetrominoType?  get nextPieceType => _engine.nextPieceType;
  TetrominoType?  get holdPieceType => _engine.holdPieceType;
  bool            get canHold       => _engine.canHold;
  int             get score         => _engine.score;
  int             get level         => _engine.level;
  int             get linesCleared  => _engine.linesCleared;
  int             get highScore     => _engine.highScore;
  GameStatus      get status        => _engine.status;

  /// Rows that were just cleared; non-empty briefly after each line clear
  /// to drive the particle animation.
  List<int>       get clearedRows   => _clearedRows;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _loadHighScore() async {
    final prefs  = await SharedPreferences.getInstance();
    final saved  = prefs.getInt('tetris_high_score') ?? 0;
    _engine.initialize(savedHighScore: saved);
    _safeNotify();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tetris_high_score', _engine.highScore);
  }

  // ── Game Lifecycle ─────────────────────────────────────────────────────────

  void startGame() {
    _engine.startGame();
    _clearedRows     = [];
    _lastFallSpeedMs = _engine.fallSpeedMs;
    _lastLevel       = _engine.level;
    _startTimer();
    _audio.startBgm();
    _safeNotify();
  }

  void pauseGame() {
    _engine.pause();
    _stopTimer();
    _audio.pauseBgm();
    _safeNotify();
  }

  void resumeGame() {
    _engine.resume();
    _lastFallSpeedMs = _engine.fallSpeedMs;
    _startTimer();
    _audio.resumeBgm();
    _safeNotify();
  }

  void restartGame() {
    _stopTimer();
    _audio.stopBgm();
    startGame();
  }

  // ── Player Actions ─────────────────────────────────────────────────────────

  void moveLeft()  {
    if (_engine.moveLeft())  { _audio.play(SoundEvent.move); }
    _safeNotify();
  }

  void moveRight() {
    if (_engine.moveRight()) { _audio.play(SoundEvent.move); }
    _safeNotify();
  }

  void softDrop()  {
    _engine.softDrop();
    _safeNotify();
  }

  void rotateCW()  {
    final prevRot = _engine.currentPiece?.rotation ?? -1;
    _engine.rotateCW();
    if (_engine.currentPiece?.rotation != prevRot) {
      _audio.play(SoundEvent.rotate);
    }
    _safeNotify();
  }

  void hardDrop() {
    final cleared = _engine.hardDrop();
    _audio.play(SoundEvent.lock);
    _handleCleared(cleared);
    _checkGameOver();
  }

  void holdPiece() {
    _engine.holdPiece();
    _safeNotify();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(
      Duration(milliseconds: _engine.fallSpeedMs),
      _onTick,
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick(Timer _) {
    final cleared = _engine.tick();

    // Lock sound when a piece settles naturally (tick returned cleared list
    // which means a piece just locked — even if no lines were cleared).
    // We detect this by checking if tick triggered a lock (cleared list is
    // returned only after _lockPiece, so any tick returning a list means lock).
    // Actually tick returns [] on regular drop and [] or [rows] on lock.
    // We play lock only when we know a lock just happened:
    // cleared != null signifies lock occurred.
    // Use a flag approach via engine's currentPiece changing.
    _handleCleared(cleared);
    _checkGameOver();

    // Restart the timer when level increases (fall speed changes).
    if (_engine.fallSpeedMs != _lastFallSpeedMs) {
      _lastFallSpeedMs = _engine.fallSpeedMs;
      _startTimer();
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _handleCleared(List<int> cleared) {
    _clearedRows = cleared;

    if (cleared.isNotEmpty) {
      // Play the appropriate clear sound.
      if (cleared.length == 4) {
        _audio.play(SoundEvent.tetris);
      } else {
        _audio.play(SoundEvent.lineClear);
      }

      // Level-up check: fired after score/level updated inside engine.
      if (_engine.level > _lastLevel) {
        _lastLevel = _engine.level;
        Future.delayed(const Duration(milliseconds: 300), () {
          _audio.play(SoundEvent.levelUp);
        });
      }
    }

    _safeNotify();

    // Reset the signal after the particle animation duration so the overlay
    // is removed from the tree on the next rebuild.
    if (cleared.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 950), () {
        if (!_disposed) {
          _clearedRows = [];
          _safeNotify();
        }
      });
    }
  }

  void _checkGameOver() {
    if (_engine.status == GameStatus.gameOver) {
      _stopTimer();
      _audio.stopBgm();
      _audio.play(SoundEvent.gameOver);
      _saveHighScore();
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    super.dispose();
  }
}
