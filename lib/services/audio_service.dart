import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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
/// Uses a dedicated [AudioPlayer] for BGM (looping) and a pool of short-lived
/// players for SFX so multiple sounds can overlap without cutting each other off.
///
/// Respects [isMuted]: when muted, no audio is produced but the service
/// continues to accept calls so the caller never needs to guard.
class AudioService extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  bool _muted = false;
  bool get isMuted => _muted;

  bool _bgmPlaying = false;

  // ── Players ────────────────────────────────────────────────────────────────

  /// Dedicated player for the looping background music.
  final AudioPlayer _bgmPlayer = AudioPlayer();

  /// Small pool of reusable SFX players so rapid events don't drop sounds.
  static const int _sfxPoolSize = 6;
  final List<AudioPlayer> _sfxPool =
      List.generate(6, (_) => AudioPlayer());
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

  // ── BGM ────────────────────────────────────────────────────────────────────

  /// Start the looping background music.  No-op if already playing or muted.
  Future<void> startBgm() async {
    if (_bgmPlaying) return;
    _bgmPlaying = true;
    if (_muted) return;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.35);
    await _bgmPlayer.play(AssetSource('audio/bgm_loop.wav'));
  }

  /// Pause the background music (e.g. on game pause).
  Future<void> pauseBgm() async {
    await _bgmPlayer.pause();
  }

  /// Resume the background music.
  Future<void> resumeBgm() async {
    if (_muted) return;
    await _bgmPlayer.resume();
  }

  /// Stop and reset the background music (e.g. on game over / restart).
  Future<void> stopBgm() async {
    _bgmPlaying = false;
    await _bgmPlayer.stop();
  }

  // ── SFX ────────────────────────────────────────────────────────────────────

  /// Play a one-shot sound effect.  Silent when [isMuted].
  Future<void> play(SoundEvent event) async {
    if (_muted) return;
    final asset = _assets[event];
    if (asset == null) return;

    // Round-robin through the pool to allow overlapping SFX.
    final player = _sfxPool[_sfxIndex % _sfxPoolSize];
    _sfxIndex++;

    await player.setReleaseMode(ReleaseMode.release);
    await player.setVolume(_volumeFor(event));
    await player.play(AssetSource(asset));
  }

  double _volumeFor(SoundEvent e) {
    switch (e) {
      case SoundEvent.move:      return 0.5;
      case SoundEvent.rotate:    return 0.55;
      case SoundEvent.lock:      return 0.7;
      case SoundEvent.lineClear: return 0.85;
      case SoundEvent.tetris:    return 1.0;
      case SoundEvent.levelUp:   return 0.9;
      case SoundEvent.gameOver:  return 0.95;
    }
  }

  // ── Mute toggle ────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      await _bgmPlayer.setVolume(0);
      for (final p in _sfxPool) { await p.setVolume(0); }
    } else {
      await _bgmPlayer.setVolume(0.35);
      // Resume BGM if a game is in progress.
      if (_bgmPlaying) await _bgmPlayer.resume();
    }
    notifyListeners();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    for (final p in _sfxPool) { await p.dispose(); }
    super.dispose();
  }
}
