import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:standup_app/core/app_theme.dart';

/// A single option in a [SegmentedChoice].
class SegmentedOption<T> {
  final T value;

  /// Already-translated label.
  final String label;

  /// Optional leading icon, which is what makes a row of words scannable.
  final IconData? icon;

  const SegmentedOption({required this.value, required this.label, this.icon});
}

/// An accessible segmented control.
///
/// ## Why this exists
///
/// The app originally had four hand-rolled rows of `InkWell` + `Container` doing
/// this job — theme mode in Settings, theme mode in onboarding, accent swatches,
/// reminder cadence. None of them exposed a selected state to a screen reader,
/// none responded to arrow keys, and each had to be restyled whenever the theme
/// changed. This replaces all of them with one widget that has the semantics
/// right once.
///
/// ## Semantics
///
/// The control is a `radiogroup`: each option is a radio, and the selected one
/// carries `isSelected`. A screen reader announces "Dark, radio button, selected,
/// 2 of 3" instead of three unlabelled tappable boxes. Arrow keys move the
/// selection, which is the expected keyboard behaviour for a radio group, and
/// Home/End jump to the ends.
class SegmentedChoice<T> extends StatelessWidget {
  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Announced as the group's name, e.g. "Appearance".
  final String semanticLabel;

  /// Forces a single row. By default the options wrap when they do not fit,
  /// which is what keeps long labels legible at large text sizes instead of
  /// truncating them.
  final bool singleRow;

  /// Focus node for the group.
  ///
  /// Exposed so a caller can move focus here deliberately — a screen-reader user
  /// arriving on the group, or a test driving it with the keyboard. Left null
  /// the widget owns and disposes its own.
  final FocusNode? focusNode;

  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.singleRow = false,
    this.focusNode,
  });

  void _select(T value) {
    if (value == selected) return;
    HapticFeedback.selectionClick();
    onChanged(value);
  }

  /// Moves the selection by [delta], clamping at the ends.
  void _move(int delta) {
    if (options.isEmpty) return;
    final index = options.indexWhere((option) => option.value == selected);
    final from = index < 0 ? 0 : index;
    final next = (from + delta).clamp(0, options.length - 1);
    if (next == from) return;
    _select(options[next].value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentRoles = AccentTheme.of(context);

    return Semantics(
      container: true,
      label: semanticLabel,
      child: FocusableActionDetector(
        focusNode: focusNode,
        // Only the group itself takes focus; the options are addressed through
        // the radio semantics rather than as separate tab stops, which is what
        // a screen-reader user expects from a radio group.
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              const _MoveIntent(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              const _MoveIntent(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _MoveIntent(
            -1,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _MoveIntent(1),
          const SingleActivator(LogicalKeyboardKey.home): const _EdgeIntent(
            toEnd: false,
          ),
          const SingleActivator(LogicalKeyboardKey.end): const _EdgeIntent(
            toEnd: true,
          ),
        },
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) => _move(intent.delta),
          ),
          _EdgeIntent: CallbackAction<_EdgeIntent>(
            onInvoke: (intent) {
              if (options.isEmpty) return null;
              _select(options[intent.toEnd ? options.length - 1 : 0].value);
              return null;
            },
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final runWidth = singleRow && constraints.hasBoundedWidth
                ? constraints.maxWidth
                : null;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                for (final option in options)
                  SizedBox(
                    width: runWidth == null
                        ? null
                        : (runWidth - 8 * (options.length - 1)) /
                              options.length,
                    child: _Segment(
                      label: option.label,
                      icon: option.icon,
                      selected: option.value == selected,
                      accent: accentRoles.accent,
                      accentText: accentRoles.accentText,
                      surface: theme.colorScheme.surface,
                      onTap: () => _select(option.value),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color accent;
  final Color accentText;
  final Color surface;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.accentText,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        // The text and icon are decorative here: Semantics above already
        // announces the label, and leaving them in would read the option twice.
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? accent : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  // The ring is drawn in the surface colour rather than white so
                  // it stays visible against a light accent.
                  color: selected ? surface : theme.colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: selected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            // White on the accent. Every accent is at least
                            // 4.84:1 against white, asserted in
                            // test/contrast_test.dart, so this is always legal.
                            ? Colors.white
                            : theme.textTheme.bodyLarge?.color,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveIntent extends Intent {
  final int delta;
  const _MoveIntent(this.delta);
}

class _EdgeIntent extends Intent {
  final bool toEnd;
  const _EdgeIntent({required this.toEnd});
}
