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
import '../widgets/settings_panel.dart';
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
///   S         : settings
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: tc.background,
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
      case LogicalKeyboardKey.keyS:
        showSettingsSheet(ctx, onOpen: () {
          if (p.status == GameStatus.playing) p.pauseGame();
        });
        return KeyEventResult.handled;
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
    final tc = ThemeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Title row: Menu | CUBICLES | Settings | Mute | Pause ───────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              _IconBtn(
                icon: Icons.menu_rounded,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'Menu',
                tc: tc,
              ),
              Expanded(
                child: Text(
                  'CUBICLES',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: tc.accent,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: tc.accent.withOpacity(0.5),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                ),
              ),
              // Settings
              Consumer<GameProvider>(
                builder: (_, p, __) => _IconBtn(
                  icon: Icons.settings_rounded,
                  onTap: () => showSettingsSheet(
                    context,
                    onOpen: () {
                      if (p.status == GameStatus.playing) p.pauseGame();
                    },
                  ),
                  tooltip: 'Settings',
                  tc: tc,
                ),
              ),
              const SizedBox(width: 4),
              // Mute toggle
              Consumer<AudioService>(
                builder: (_, audio, __) => _IconBtn(
                  icon: audio.isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: audio.toggleMute,
                  tooltip: audio.isMuted ? 'Unmute' : 'Mute',
                  tc: tc,
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
                  tc: tc,
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
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: tc.accent.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ScoreStat(label: 'SCORE', value: p.score, accent: tc.accent),
            _VertDivider(tc: tc),
            _ScoreStat(label: 'BEST',  value: p.highScore, accent: AppColors.warning),
            _VertDivider(tc: tc),
            _ScoreStat(label: 'LEVEL', value: p.level,  accent: AppColors.success),
            _VertDivider(tc: tc),
            _ScoreStat(label: 'LINES', value: p.linesCleared, accent: const Color(0xFFD500F9)),
          ],
        ),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final ThemeColors tc;
  const _VertDivider({required this.tc});

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: tc.border.withValues(alpha: 0.6),
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
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent.withValues(alpha: 0.9),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
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
                  color: label == 'BEST' ? AppColors.warning : tc.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final ThemeColors tc;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, color: tc.textSecondary, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: tc.surface,
          side: BorderSide(color: tc.border.withValues(alpha: 0.6), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME AREA  (responsive)
// ═══════════════════════════════════════════════════════════════════════════════

class _GameArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide    = constraints.maxWidth > 520;
        final hPad      = isWide ? 12.0 : 8.0;
        final previewSz = isWide ? 100.0 : 64.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top strip: Hold | Next (+ keyboard hints on wide screens) ──
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 6),
              child: Consumer<GameProvider>(
                builder: (_, p, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewCard(
                      label: 'HOLD',
                      pieceType: p.holdPieceType,
                      previewSize: previewSz,
                      isDisabled: !p.canHold,
                      onTap: p.holdPiece,
                      tc: tc,
                    ),
                    const SizedBox(width: 10),
                    _PreviewCard(
                      label: 'NEXT',
                      pieceType: p.nextPieceType,
                      previewSize: previewSz,
                      tc: tc,
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 10),
                      Expanded(child: _KeyboardHints(tc: tc)),
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
  final ThemeColors tc;

  const _PreviewCard({
    required this.label,
    required this.pieceType,
    required this.previewSize,
    required this.tc,
    this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPiece = pieceType != null;
    final pieceColor = hasPiece ? AppColors.tetrominoes[pieceType!.colorIndex] : tc.accent;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.40 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tc.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (onTap != null && !isDisabled && hasPiece)
                  ? pieceColor.withValues(alpha: 0.5)
                  : tc.border.withValues(alpha: 0.8),
              width: (onTap != null && !isDisabled && hasPiece) ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (hasPiece && !isDisabled)
                BoxShadow(
                  color: pieceColor.withValues(alpha: 0.10),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: (onTap != null && !isDisabled) ? tc.accent : tc.textMuted,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
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
    ('S', 'Settings'),
    ('P / Esc', 'Pause'),
  ];

  final ThemeColors tc;
  const _KeyboardHints({required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEYBOARD',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tc.textMuted,
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
                      color: tc.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: tc.accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      h.$1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: tc.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      h.$2,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: tc.textSecondary,
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
