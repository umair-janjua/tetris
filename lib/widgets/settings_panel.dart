import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC HELPER
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the settings panel as an animated bottom sheet.
///
/// Pass [onOpen] to run code before the sheet opens (e.g. pause the game).
void showSettingsSheet(BuildContext context, {VoidCallback? onOpen}) {
  onOpen?.call();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => const SettingsPanel(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PANEL
// ─────────────────────────────────────────────────────────────────────────────

/// Glassmorphism settings bottom sheet with music, vibration, mode, and theme.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final settings = context.watch<SettingsProvider>();
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(
        left: 12, right: 12,
        bottom: mq.viewInsets.bottom + mq.padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tc.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: tc.accent.withOpacity(0.12),
            blurRadius: 32,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tc.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // ── Title ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_rounded, color: tc.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SETTINGS',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: tc.textPrimary,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),

          // ── Settings rows ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _Divider(tc: tc),

                // Music on/off
                _SwitchRow(
                  tc: tc,
                  icon: settings.musicEnabled
                      ? Icons.music_note_rounded
                      : Icons.music_off_rounded,
                  label: 'Music',
                  subtitle: settings.musicEnabled ? 'Background music on' : 'Muted',
                  value: settings.musicEnabled,
                  onChanged: (v) => settings.setMusicEnabled(v),
                ),

                _Divider(tc: tc),

                // Vibration on level change
                _SwitchRow(
                  tc: tc,
                  icon: Icons.vibration_rounded,
                  label: 'Vibrate on Level Up',
                  subtitle: 'Haptic feedback on new level',
                  value: settings.vibrateOnLevelUp,
                  onChanged: (v) => settings.setVibrateOnLevelUp(v),
                ),

                _Divider(tc: tc),

                // Game Mode
                _ModeRow(tc: tc, settings: settings),

                _Divider(tc: tc),

                // Theme
                _ThemeRow(tc: tc, settings: settings),

                _Divider(tc: tc),
              ],
            ),
          ),

          // ── Close button ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('DONE'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final ThemeColors tc;
  const _Divider({required this.tc});

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: tc.border.withOpacity(0.5),
        margin: const EdgeInsets.symmetric(vertical: 2),
      );
}

class _SwitchRow extends StatelessWidget {
  final ThemeColors tc;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.tc,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Icon chip
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: value
                  ? tc.accent.withOpacity(0.15)
                  : tc.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value
                    ? tc.accent.withOpacity(0.4)
                    : tc.border.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: value ? tc.accent : tc.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tc.textMuted,
                      ),
                ),
              ],
            ),
          ),

          // Switch
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: tc.accent,
          ),
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final ThemeColors tc;
  final SettingsProvider settings;

  const _ModeRow({required this.tc, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tc.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tc.warning.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Icon(Icons.speed_rounded, color: tc.warning, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Game Mode',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    settings.gameMode.description,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tc.textMuted,
                        ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Segmented mode picker
          Row(
            children: GameMode.values.map((mode) {
              final selected = settings.gameMode == mode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _ModeChip(
                    tc: tc,
                    label: mode.label,
                    selected: selected,
                    onTap: () => settings.setGameMode(mode),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final ThemeColors tc;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.tc,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? tc.accent.withOpacity(0.18)
              : tc.surfaceHigh.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tc.accent.withOpacity(0.6) : tc.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? tc.accent : tc.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final ThemeColors tc;
  final SettingsProvider settings;

  const _ThemeRow({required this.tc, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = settings.themeMode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Icon chip
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF6366F1).withOpacity(0.15)
                  : const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF6366F1).withOpacity(0.4)
                    : const Color(0xFFF59E0B).withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark
                  ? const Color(0xFF818CF8)
                  : const Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Dark mode' : 'Light mode',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tc.textMuted,
                      ),
                ),
              ],
            ),
          ),

          // Dark / Light toggle pill
          GestureDetector(
            onTap: () => settings.toggleTheme(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 72,
              height: 36,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3730A3).withOpacity(0.3)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF6366F1).withOpacity(0.5)
                      : const Color(0xFFF59E0B).withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: isDark ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFF59E0B),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFFF59E0B))
                                .withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        size: 16,
                        color: Colors.white,
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
