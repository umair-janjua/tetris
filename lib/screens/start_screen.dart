import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

/// Home / start screen shown before the game begins.
///
/// Features a pulsing neon title, high-score display, controls legend,
/// and an animated slide-in entrance.
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
      pageBuilder:      (_, __, ___) => const GameScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final highScore = context.select<GameProvider, int>((p) => p.highScore);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    AppColors.accent.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
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
                        // ── Title ──────────────────────────────────────────
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (_, __) => _buildTitle(context),
                        ),

                        const SizedBox(height: 8),
                        Text(
                          'THE CLASSIC GAME · REBORN',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 3,
                              ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 44),

                        // ── High score chip ────────────────────────────────
                        if (highScore > 0) ...[
                          _HighScoreBadge(score: highScore),
                          const SizedBox(height: 28),
                        ],

                        // ── Play button ────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startGame,
                            child: const Text('PLAY'),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Controls legend ────────────────────────────────
                        _ControlsLegend(),
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
        colors: [Color(0xFF38BDF8), Color(0xFF22C55E), Color(0xFF38BDF8)],
      ).createShader(bounds),
      child: Text(
        'TETRIS',
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white, // Required for ShaderMask
              shadows: [
                Shadow(
                  color: AppColors.accent
                      .withOpacity(_glowAnim.value * 0.75),
                  blurRadius: 28 * _glowAnim.value,
                ),
              ],
            ),
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _HighScoreBadge extends StatelessWidget {
  final int score;
  const _HighScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
            color: AppColors.warning.withOpacity(0.45), width: 1.2),
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
  final _items = const [
    ('TAP', 'Rotate piece'),
    ('SWIPE ← →', 'Move left / right'),
    ('SWIPE ↓', 'Soft drop'),
    ('HOLD', 'Hard drop'),
    ('HOLD PANEL', 'Stash piece'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'HOW TO PLAY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
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
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        item.$1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: Theme.of(context).textTheme.bodyMedium,
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
