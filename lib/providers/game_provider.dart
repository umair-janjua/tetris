import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/game_engine.dart';
import '../models/tetromino.dart';
import '../services/audio_service.dart';
import 'settings_provider.dart';

/// Sits between [GameEngine] and the UI.
///
/// Responsibilities:
/// - Owns and drives the gravity [Timer].
/// - Persists / loads the high score via [SharedPreferences].
/// - Exposes game state to the widget tree and calls [notifyListeners].
/// - Fires audio events via [AudioService] at every meaningful game moment.
/// - Fires haptic feedback on level-up when enabled in [SettingsProvider].
/// - Keeps the engine's [GameMode] in sync with [SettingsProvider].
/// - Pauses the game when the app leaves the foreground.
class GameProvider extends ChangeNotifier with WidgetsBindingObserver {
  final GameEngine   _engine = GameEngine();
  final AudioService _audio;
  final SettingsProvider _settings;

  /// Gravity timer: steps the piece down one row per [GameEngine.fallSpeedMs].
  Timer? _gravityTimer;

  /// Clears the particle signal once the burst animation has finished.
  Timer? _clearSignalTimer;

  /// Tracks last known fall speed so the timer is restarted when it changes.
  int _lastFallSpeedMs = 0;

  /// Tracks the previous level to detect level-up events.
  int _lastLevel = 1;

  /// Rows cleared on the most recent lock (used to trigger particle animation).
  List<int> _clearedRows = [];

  /// Monotonic id bumped once per line clear. The particle overlay keys off
  /// this so it is rebuilt exactly once per burst rather than on every frame.
  int _clearId = 0;

  /// Guard against notifying after dispose.
  bool _disposed = false;

  GameProvider({required AudioService audio, required SettingsProvider settings})
      : _audio = audio, _settings = settings {
    _loadHighScore();
    _settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Getters (mirror GameEngine) ────────────────────────────────────────────
  List<List<int>> get board         => _engine.board;
  int             get boardVersion  => _engine.boardVersion;
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
  GameMode        get gameMode      => _engine.gameMode;

  /// Rows that were just cleared; non-empty briefly after each line clear
  /// to drive the particle animation.
  List<int>       get clearedRows   => _clearedRows;

  /// Direct engine access so `tool/generate_screenshots.dart` can stage a
  /// board for store artwork. Not used by the app itself.
  @visibleForTesting
  GameEngine get engine => _engine;

  /// Identifies the current burst; see [_clearId].
  int             get clearId       => _clearId;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _loadHighScore() async {
    final prefs  = await SharedPreferences.getInstance();
    final saved  = prefs.getInt('cubicles_high_score') ?? prefs.getInt('tetris_high_score') ?? 0;
    _engine.initialize(savedHighScore: saved);
    _safeNotify();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cubicles_high_score', _engine.highScore);
  }

  // ── Settings / lifecycle reactions ─────────────────────────────────────────

  /// Apply a mode change immediately instead of waiting for the next game.
  void _onSettingsChanged() {
    if (_engine.gameMode == _settings.gameMode) return;
    _engine.gameMode = _settings.gameMode;
    if (_engine.status == GameStatus.playing) {
      _restartGravityTimer();
    }
    _safeNotify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Anything other than "visible and interactive" must not keep the piece
    // falling — a backgrounded game would otherwise top out unattended.
    if (state != AppLifecycleState.resumed &&
        _engine.status == GameStatus.playing) {
      pauseGame();
    }
  }

  // ── Game Lifecycle ─────────────────────────────────────────────────────────

  void startGame() {
    // Apply current game mode from settings before starting.
    _engine.gameMode = _settings.gameMode;
    _engine.startGame();
    _clearSignalTimer?.cancel();
    _clearedRows     = [];
    _lastFallSpeedMs = _engine.fallSpeedMs;
    _lastLevel       = _engine.level;
    _restartGravityTimer();
    _audio.startBgm();
    _safeNotify();
  }

  void pauseGame() {
    if (_engine.status != GameStatus.playing) return;
    _engine.pause();
    _stopGravityTimer();
    _audio.pauseBgm();
    _safeNotify();
  }

  void resumeGame() {
    if (_engine.status != GameStatus.paused) return;
    _engine.resume();
    _lastFallSpeedMs = _engine.fallSpeedMs;
    _restartGravityTimer();
    _audio.resumeBgm();
    _safeNotify();
  }

  void restartGame() {
    _stopGravityTimer();
    // stopBgm/startBgm are queued inside AudioService, so the stop can never
    // land after the restart's play and silence the new track.
    _audio.stopBgm();
    startGame();
  }

  /// Leave the game running but bring it to a safe stop — used when the player
  /// navigates away from the game screen.
  void leaveGame() {
    pauseGame();
    _audio.stopBgm();
  }

  // ── Player Actions ─────────────────────────────────────────────────────────

  void moveLeft()  {
    if (_engine.moveLeft()) _audio.play(SoundEvent.move);
    _safeNotify();
  }

  void moveRight() {
    if (_engine.moveRight()) _audio.play(SoundEvent.move);
    _safeNotify();
  }

  void softDrop()  {
    _engine.softDrop();
    _safeNotify();
  }

  void rotateCW()  => _rotate(RotationDir.cw);
  void rotateCCW() => _rotate(RotationDir.ccw);

  void _rotate(RotationDir dir) {
    if (_engine.rotate(dir)) _audio.play(SoundEvent.rotate);
    _safeNotify();
  }

  void hardDrop() {
    if (_engine.status != GameStatus.playing || _engine.currentPiece == null) {
      return;
    }
    final cleared = _engine.hardDrop();
    _audio.play(SoundEvent.lock);
    _handleCleared(cleared);
    _checkGameOver();
  }

  void holdPiece() {
    if (_engine.holdPiece()) _checkGameOver();
    _safeNotify();
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void _restartGravityTimer() {
    _stopGravityTimer();
    _lastFallSpeedMs = _engine.fallSpeedMs;
    _gravityTimer = Timer.periodic(
      Duration(milliseconds: _engine.fallSpeedMs),
      _onGravityTick,
    );
  }

  void _stopGravityTimer() {
    _gravityTimer?.cancel();
    _gravityTimer = null;
  }

  void _onGravityTick(Timer _) {
    // boardVersion only moves when the engine commits a piece, which is how we
    // know a natural (non-hard-drop) lock happened and should be heard.
    final versionBefore = _engine.boardVersion;
    final cleared = _engine.tick();
    if (_engine.boardVersion != versionBefore) {
      _audio.play(SoundEvent.lock);
    }

    _handleCleared(cleared);
    _checkGameOver();

    // Restart the gravity timer when level (and therefore speed) changes.
    if (_engine.fallSpeedMs != _lastFallSpeedMs) {
      _restartGravityTimer();
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _handleCleared(List<int> cleared) {
    _clearedRows = cleared;

    if (cleared.isNotEmpty) {
      _clearId++;

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
          if (!_disposed) _audio.play(SoundEvent.levelUp);
        });

        // Haptic feedback on level-up (mobile only, no-op on desktop).
        if (_settings.vibrateOnLevelUp) {
          HapticFeedback.mediumImpact();
        }
      }

      // Reset the signal after the particle animation duration so the overlay
      // is removed from the tree on the next rebuild. Held in a cancellable
      // timer so a fresh burst is never cut short by a previous one.
      _clearSignalTimer?.cancel();
      _clearSignalTimer = Timer(const Duration(milliseconds: 950), () {
        _clearedRows = [];
        _safeNotify();
      });
    }

    _safeNotify();
  }

  void _checkGameOver() {
    if (_engine.status == GameStatus.gameOver) {
      _stopGravityTimer();
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
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    _stopGravityTimer();
    _clearSignalTimer?.cancel();
    super.dispose();
  }
}
