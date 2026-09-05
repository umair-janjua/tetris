import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_panel.dart';
import 'game_screen.dart';

/// Home / start screen shown before the game begins.
///
/// Features a pulsing neon title, high-score display, controls legend,
/// a settings button, and an animated slide-in entrance.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _glowAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Pulsing glow on the title
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Content slides up and fades in on entry
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    context.read<GameProvider>().startGame();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, _, _) => const GameScreen(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  void _openSettings() {
    showSettingsSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final highScore = context.select<GameProvider, int>((p) => p.highScore);
    final gameMode = context.select<SettingsProvider, GameMode>(
        (s) => s.gameMode);

    return Scaffold(
      backgroundColor: tc.background,
      body: Stack(
        children: [
          // Radial glow background decoration
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 1.1,
                  colors: [
                    tc.accent.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Settings button (top-right corner) ─────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _SettingsIconButton(onTap: _openSettings, tc: tc),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // ── Title ───────────────────────────────────────
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (_, _) => _buildTitle(context),
                        ),

                        const SizedBox(height: 8),
                        Text(
                          '12-COLUMN CYBER EDITION',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: tc.textMuted,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w800,
                              ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 14),

                        // ── Mode badge ──────────────────────────────────
                        _ModeBadge(mode: gameMode, tc: tc),

                        const SizedBox(height: 28),

                        // ── High score chip ─────────────────────────────
                        if (highScore > 0) ...[
                          _HighScoreBadge(score: highScore, tc: tc),
                          const SizedBox(height: 24),
                        ],

                        // ── Play button ─────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startGame,
                            child: const Text('PLAY'),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Settings button ─────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openSettings,
                            icon: Icon(Icons.settings_rounded,
                                size: 18, color: tc.textPrimary),
                            label: Text(
                              'SETTINGS',
                              style: TextStyle(color: tc.textPrimary),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Controls legend ─────────────────────────────
                        _ControlsLegend(tc: tc),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF00E5FF), Color(0xFF22C55E), Color(0xFF00E5FF)],
      ).createShader(bounds),
      child: Text(
        'CUBICLES',
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 42,
              letterSpacing: 4,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: AppColors.accent
                      .withValues(alpha: _glowAnim.value * 0.75),
                  blurRadius: 28 * _glowAnim.value,
                ),
              ],
            ),
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _SettingsIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final ThemeColors tc;
  const _SettingsIconButton({required this.onTap, required this.tc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: tc.accent.withValues(alpha: 0.10),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(Icons.settings_rounded, color: tc.textSecondary, size: 22),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final GameMode mode;
  final ThemeColors tc;
  const _ModeBadge({required this.mode, required this.tc});

  Color get _color {
    switch (mode) {
      case GameMode.classic:  return tc.accent;
      case GameMode.speed:    return AppColors.error;
      case GameMode.marathon: return AppColors.success;
    }
  }

  IconData get _icon {
    switch (mode) {
      case GameMode.classic:  return Icons.grid_on_rounded;
      case GameMode.speed:    return Icons.bolt_rounded;
      case GameMode.marathon: return Icons.timer_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _color.withValues(alpha: 0.40), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 14),
          const SizedBox(width: 6),
          Text(
            '${mode.label.toUpperCase()} MODE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _HighScoreBadge extends StatelessWidget {
  final int score;
  final ThemeColors tc;
  const _HighScoreBadge({required this.score, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Text(
            'BEST  $score',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ControlsLegend extends StatelessWidget {
  final ThemeColors tc;
  const _ControlsLegend({required this.tc});

  final _items = const [
    ('TAP', 'Rotate piece'),
    ('SWIPE ← →', 'Move left / right'),
    ('SWIPE ↓', 'Soft drop'),
    ('FLICK ↓', 'Hard drop'),
    ('LONG PRESS', 'Hard drop'),
    ('HOLD PANEL', 'Stash piece'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'HOW TO PLAY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tc.textMuted,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          ..._items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tc.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: tc.accent.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        item.$1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: tc.accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tc.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
