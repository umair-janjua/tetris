import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// Displays score, personal best, level, and lines cleared.
class ScorePanelWidget extends StatelessWidget {
  const ScorePanelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GameProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Item(label: 'SCORE', value: p.score),
        const SizedBox(height: 8),
        _Item(label: 'BEST',  value: p.highScore, highlight: true),
        const SizedBox(height: 8),
        _Item(label: 'LEVEL', value: p.level),
        const SizedBox(height: 8),
        _Item(label: 'LINES', value: p.linesCleared),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;

  const _Item({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.warning : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: highlight
              ? AppColors.warning.withOpacity(0.35)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent.withOpacity(0.8),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 1),
          // Animate value changes with a count-up feel
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              value.toString(),
              key: ValueKey(value),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: highlight ? AppColors.warning : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
