import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SOUND EVENT ENUM
// ═══════════════════════════════════════════════════════════════════════════════

/// Every distinct audio event the game can fire.
enum SoundEvent {
  move,       // piece shifted left/right
  rotate,     // piece rotated
  lock,       // piece locked to the board
  lineClear,  // 1–3 lines cleared
  tetris,     // 4 lines cleared (Tetris!)
  levelUp,    // level increased
  gameOver,   // game ended
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIO SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

/// Manages all game audio: background music + sound effects.
///
/// Configures audio context so BGM and SFX can play simultaneously
/// without interrupting, ducking, or pausing each other.
///
/// Every BGM operation is appended to a single serialized queue. Callers fire
/// them synchronously (`stopBgm(); startBgm();`) and still get them applied in
/// order, so a slow `stop()` can never land after a later `play()` and leave
/// the game silent.
class AudioService extends ChangeNotifier {
  // ── Dependencies ───────────────────────────────────────────────────────────

  final SettingsProvider _settings;

  // ── Derived mute state ─────────────────────────────────────────────────────

  /// True when music is disabled by the user (mirrors settings).
  bool get isMuted => !_settings.musicEnabled;

  static const double _bgmVolume = 0.75;

  /// The game wants background music (a round is in progress).
  bool _bgmWanted = false;

  /// The BGM player currently has a source loaded.
  bool _bgmLoaded = false;

  /// BGM is paused because the *game* is paused (as opposed to muted).
  bool _bgmPaused = false;

  /// Serializes every BGM operation. See the class doc.
  Future<void> _bgmQueue = Future<void>.value();

  // ── Players ────────────────────────────────────────────────────────────────

  /// Dedicated player for the looping background music.
  final AudioPlayer _bgmPlayer = AudioPlayer();

  /// Small pool of low-latency SFX players so rapid events overlap cleanly.
  static const int _sfxPoolSize = 6;
  late final List<AudioPlayer> _sfxPool;
  int _sfxIndex = 0;

  // ── Asset paths ────────────────────────────────────────────────────────────

  static const String _bgmAsset = 'audio/leberch-playful-441727.m4a';

  static const Map<SoundEvent, String> _assets = {
    SoundEvent.move:      'audio/move.wav',
    SoundEvent.rotate:    'audio/rotate.wav',
    SoundEvent.lock:      'audio/lock.wav',
    SoundEvent.lineClear: 'audio/line_clear.wav',
    SoundEvent.tetris:    'audio/tetris.wav',
    SoundEvent.levelUp:   'audio/level_up.wav',
    SoundEvent.gameOver:  'audio/game_over.wav',
  };

  AudioService({required SettingsProvider settings}) : _settings = settings {
    _initAudioContext();
    _sfxPool = List.generate(_sfxPoolSize, (_) {
      final p = AudioPlayer();
      p.setPlayerMode(PlayerMode.lowLatency);
      p.setReleaseMode(ReleaseMode.stop);
      return p;
    });

    _settings.addListener(_onSettingsChanged);
  }

  void _initAudioContext() {
    // Configure global audio context for multi-stream mixing (no audio focus hijacking).
    AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ),
    );

    _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  /// Append [action] to the serialized BGM queue.
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _bgmQueue.then((_) => action()).catchError((Object e) {
      debugPrint('BGM operation failed: $e');
    });
    _bgmQueue = next;
    return next;
  }

  void _onSettingsChanged() {
    if (isMuted) {
      // Stop feeding the speaker rather than just zeroing the volume.
      _enqueue(() => _bgmPlayer.pause());
    } else if (_bgmWanted && !_bgmPaused) {
      // Unmuting mid-round has to *start* the track when the round began muted:
      // the player has no source loaded yet, so resume() alone would be silent.
      _enqueue(_playBgmFromCurrentState);
    }
    notifyListeners();
  }

  // ── BGM ────────────────────────────────────────────────────────────────────

  /// Load and play the loop from the top.
  Future<void> _loadAndPlayBgm() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_bgmVolume);
    await _bgmPlayer.play(AssetSource(_bgmAsset));
    _bgmLoaded = true;
  }

  /// Resume if a source is already loaded, otherwise start it.
  Future<void> _playBgmFromCurrentState() async {
    if (isMuted) return;
    if (!_bgmLoaded) {
      await _loadAndPlayBgm();
    } else {
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.resume();
    }
  }

  /// Start the looping background music.  No-op if already playing.
  Future<void> startBgm() {
    _bgmWanted = true;
    _bgmPaused = false;
    return _enqueue(() async {
      if (isMuted) return; // _onSettingsChanged will start it on unmute
      if (_bgmLoaded) return;
      await _loadAndPlayBgm();
    });
  }

  /// Pause the background music (e.g. on game pause).
  Future<void> pauseBgm() {
    _bgmPaused = true;
    return _enqueue(() => _bgmPlayer.pause());
  }

  /// Resume the background music.
  Future<void> resumeBgm() {
    _bgmPaused = false;
    return _enqueue(_playBgmFromCurrentState);
  }

  /// Stop and reset the background music (e.g. on game over / restart).
  Future<void> stopBgm() {
    _bgmWanted = false;
    _bgmPaused = false;
    return _enqueue(() async {
      await _bgmPlayer.stop();
      _bgmLoaded = false;
    });
  }

  // ── SFX ────────────────────────────────────────────────────────────────────

  /// Play a one-shot sound effect simultaneously with background music.
  Future<void> play(SoundEvent event) async {
    if (isMuted) return;
    final asset = _assets[event];
    if (asset == null) return;

    try {
      // Round-robin through the low-latency pool to allow overlapping SFX.
      final player = _sfxPool[_sfxIndex % _sfxPoolSize];
      _sfxIndex++;

      await player.setVolume(_volumeFor(event));
      await player.play(AssetSource(asset), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Error playing SFX $event: $e');
    }
  }

  double _volumeFor(SoundEvent e) {
    switch (e) {
      case SoundEvent.move:      return 0.45;
      case SoundEvent.rotate:    return 0.50;
      case SoundEvent.lock:      return 0.65;
      case SoundEvent.lineClear: return 0.80;
      case SoundEvent.tetris:    return 0.95;
      case SoundEvent.levelUp:   return 0.85;
      case SoundEvent.gameOver:  return 0.90;
    }
  }

  // ── Mute toggle (legacy helper, kept for keyboard shortcut) ───────────────

  Future<void> toggleMute() async {
    await _settings.toggleMusic();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _settings.removeListener(_onSettingsChanged);
    await _bgmPlayer.dispose();
    for (final p in _sfxPool) {
      await p.dispose();
    }
    super.dispose();
  }
}
