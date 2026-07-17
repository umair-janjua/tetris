import 'package:flutter/material.dart';
import '../models/tetromino.dart';
import '../painters/piece_painter.dart';
import '../theme/app_theme.dart';

/// Displays a labeled tetromino piece in a neon-bordered box.
///
/// Used for both the NEXT piece preview and the HOLD piece slot.
/// When [onTap] is provided, the box is tappable (for hold action).
/// When [isDisabled] is true (hold already used), the box is dimmed.
class PiecePreviewWidget extends StatelessWidget {
  final String label;
  final TetrominoType? pieceType;
  final double size;
  final VoidCallback? onTap;
  final bool isDisabled;

  const PiecePreviewWidget({
    super.key,
    required this.label,
    this.pieceType,
    this.size = 80,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label row
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),

            // Piece preview box
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDisabled
                      ? AppColors.border.withOpacity(0.3)
                      : (onTap != null
                          ? AppColors.accent.withOpacity(0.4)
                          : AppColors.border),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: CustomPaint(
                  painter: PiecePainter(pieceType: pieceType),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
