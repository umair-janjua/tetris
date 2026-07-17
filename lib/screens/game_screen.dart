import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../engine/game_engine.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../models/tetromino.dart';
import '../painters/piece_painter.dart';
import '../services/audio_service.dart';
import '../widgets/game_board_widget.dart';
import 'game_over_overlay.dart';
import 'pause_overlay.dart';

/// Main gameplay screen.
///
/// Responsive layout:
/// - Narrow (phones): compact 80 px side panels
/// - Wide (tablets/desktop): 160 px side panels with controls hint
///
/// Keyboard shortcuts (desktop):
///   Arrow ← → : move   |  Arrow ↑ / X : rotate
///   Arrow ↓   : soft drop   |  Space : hard drop
///   C / Shift : hold   |  P / Esc : pause
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              // ── Main game layout ─────────────────────────────────────────
              Column(
                children: [
                  _Header(),
                  Expanded(child: _GameArea()),
                ],
              ),

              // ── State overlays ───────────────────────────────────────────
              Consumer<GameProvider>(
                builder: (_, p, __) {
                  if (p.status == GameStatus.paused)   return const PauseOverlay();
                  if (p.status == GameStatus.gameOver) return const GameOverOverlay();
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle physical keyboard input for desktop / emulator users.
  static KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final ctx = node.context;
    if (ctx == null) return KeyEventResult.ignored;
    final p = ctx.read<GameProvider>();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        p.moveLeft(); return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        p.moveRight(); return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        p.softDrop(); return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyX:
        p.rotateCW(); return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        p.hardDrop(); return KeyEventResult.handled;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.shiftLeft:
      case LogicalKeyboardKey.shiftRight:
        p.holdPiece(); return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        ctx.read<AudioService>().toggleMute(); return KeyEventResult.handled;
      case LogicalKeyboardKey.keyP:
      case LogicalKeyboardKey.escape:
        if (p.status == GameStatus.playing) { p.pauseGame(); }
        else if (p.status == GameStatus.paused) { p.resumeGame(); }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Title row: Menu | TETRIS | Pause ─────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              _IconBtn(
                icon: Icons.menu_rounded,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'Menu',
              ),
              Expanded(
                child: Text(
                  'TETRIS',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.accent,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: AppColors.accent.withOpacity(0.5),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                ),
              ),
              // Mute toggle
              Consumer<AudioService>(
                builder: (_, audio, __) => _IconBtn(
                  icon: audio.isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: audio.toggleMute,
                  tooltip: audio.isMuted ? 'Unmute' : 'Mute',
                ),
              ),
              const SizedBox(width: 4),
              // Pause / Resume
              Consumer<GameProvider>(
                builder: (_, p, __) => _IconBtn(
                  icon: p.status == GameStatus.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onTap: () {
                    if (p.status == GameStatus.playing) { p.pauseGame(); }
                    else if (p.status == GameStatus.paused) { p.resumeGame(); }
                  },
                  tooltip: p.status == GameStatus.paused ? 'Resume' : 'Pause',
                ),
              ),
            ],
          ),
        ),

        // ── Score bar ─────────────────────────────────────────────────────
        const _ScoreBar(),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Compact horizontal score strip shown at the top of the game screen.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GameProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ScoreStat(label: 'SCORE', value: p.score, accent: AppColors.accent),
            _Divider(),
            _ScoreStat(label: 'BEST',  value: p.highScore, accent: AppColors.warning),
            _Divider(),
            _ScoreStat(label: 'LEVEL', value: p.level,  accent: AppColors.accent),
            _Divider(),
            _ScoreStat(label: 'LINES', value: p.linesCleared, accent: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: AppColors.border,
      );
}

class _ScoreStat extends StatelessWidget {
  final String label;
  final int value;
  final Color accent;

  const _ScoreStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent.withOpacity(0.75),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              value.toString(),
              key: ValueKey(value),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: label == 'BEST' ? AppColors.warning : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.textSecondary, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME AREA  (responsive)
// ═══════════════════════════════════════════════════════════════════════════════

class _GameArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide    = constraints.maxWidth > 520;
        final hPad      = isWide ? 12.0 : 8.0;
        final previewSz = isWide ? 110.0 : 70.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top strip: Hold | Next (+ keyboard hints on wide screens) ──
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 6),
              child: Consumer<GameProvider>(
                builder: (_, p, __) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewCard(
                      label: 'HOLD',
                      pieceType: p.holdPieceType,
                      previewSize: previewSz,
                      isDisabled: !p.canHold,
                      onTap: p.holdPiece,
                    ),
                    const SizedBox(width: 10),
                    _PreviewCard(
                      label: 'NEXT',
                      pieceType: p.nextPieceType,
                      previewSize: previewSz,
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 10),
                      Expanded(child: _KeyboardHints()),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
            ),

            // ── Game board – full width, fills all remaining height ──────────
            const Expanded(child: GameBoardWidget()),

            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

/// Compact piece-preview card shown in the top strip (Hold / Next).
class _PreviewCard extends StatelessWidget {
  final String label;
  final TetrominoType? pieceType;
  final double previewSize;
  final VoidCallback? onTap;
  final bool isDisabled;

  const _PreviewCard({
    required this.label,
    required this.pieceType,
    required this.previewSize,
    this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (onTap != null && !isDisabled)
                  ? AppColors.accent.withOpacity(0.35)
                  : AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: previewSize,
                height: previewSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: PiecePainter(pieceType: pieceType),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Keyboard hints (wide layout only) ─────────────────────────────────────────

class _KeyboardHints extends StatelessWidget {
  static const _hints = [
    ('← →', 'Move'),
    ('↑ / X', 'Rotate'),
    ('↓', 'Soft drop'),
    ('SPACE', 'Hard drop'),
    ('C', 'Hold'),
    ('M', 'Mute'),
    ('P / Esc', 'Pause'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEYBOARD',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 8),
          ..._hints.map(
            (h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      h.$1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      h.$2,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
