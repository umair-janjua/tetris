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
class AudioService extends ChangeNotifier {
  // ── Dependencies ───────────────────────────────────────────────────────────

  final SettingsProvider _settings;

  // ── Derived mute state ─────────────────────────────────────────────────────

  /// True when music is disabled by the user (mirrors settings).
  bool get isMuted => !_settings.musicEnabled;

  bool _bgmPlaying = false;

  // ── Players ────────────────────────────────────────────────────────────────

  /// Dedicated player for the looping background music.
  final AudioPlayer _bgmPlayer = AudioPlayer();

  /// Small pool of low-latency SFX players so rapid events overlap cleanly.
  static const int _sfxPoolSize = 6;
  late final List<AudioPlayer> _sfxPool;
  int _sfxIndex = 0;

  // ── Asset paths ────────────────────────────────────────────────────────────

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

  void _onSettingsChanged() {
    if (isMuted) {
      _bgmPlayer.setVolume(0);
      for (final p in _sfxPool) {
        p.setVolume(0);
      }
    } else {
      _bgmPlayer.setVolume(0.75);
      if (_bgmPlaying) {
        _bgmPlayer.resume();
      }
    }
    notifyListeners();
  }

  // ── BGM ────────────────────────────────────────────────────────────────────

  /// Start the looping background music.  No-op if already playing or muted.
  Future<void> startBgm() async {
    if (_bgmPlaying) return;
    _bgmPlaying = true;
    if (isMuted) return;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.75);
      await _bgmPlayer.play(AssetSource('audio/leberch-playful-441727.m4a'));
    } catch (e) {
      debugPrint('Error playing BGM: $e');
    }
  }

  /// Pause the background music (e.g. on game pause).
  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  /// Resume the background music.
  Future<void> resumeBgm() async {
    if (isMuted) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  /// Stop and reset the background music (e.g. on game over / restart).
  Future<void> stopBgm() async {
    _bgmPlaying = false;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
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
