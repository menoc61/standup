import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:standup_app/services/haptics_service.dart';

class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final double scaleFactor;
  final bool isFullWidth;

  /// Accessible name. When null the child text is used, which works for the
  /// common case; pass an explicit label when the visual content is an icon.
  final String? semanticLabel;

  const SpringButton({
    super.key,
    required this.child,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius,
    this.border,
    this.scaleFactor = 0.94,
    this.isFullWidth = false,
    this.semanticLabel,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut,
            reverseCurve: Curves.easeOutBack,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      HapticsService.selection();
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bg = widget.backgroundColor ?? theme.colorScheme.secondary;
    final r = widget.borderRadius ?? BorderRadius.circular(16);

    Widget content = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: reduceMotion
              ? 1
              : _scaleAnimation.value * (_isHovered ? 1.02 : 1.0),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: r,
              border:
                  widget.border ??
                  // A visible focus ring: without one, keyboard and switch users
                  // have no way to tell which control is focused.
                  (_hasFocus
                      ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                      : null),
              boxShadow: [
                if (_hasFocus)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                if (_isHovered)
                  BoxShadow(
                    color: bg.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Center(
              widthFactor: widget.isFullWidth ? null : 1.0,
              child: DefaultTextStyle(
                style: TextStyle(
                  color: widget.foregroundColor ?? Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      // A bare GestureDetector produces an unnamed tap target, so assistive
      // technology announced these as buttons with no label and no enabled
      // state. Merging the child into a single semantic node fixes both, and
      // `button: true` plus `enabled` lets a screen reader say what the control
      // is and whether it currently works.
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        excludeSemantics: true,
        label: widget.semanticLabel,
        child: FocusableActionDetector(
          enabled: widget.onTap != null,
          mouseCursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          // Keyboard and switch users need a focus node and a way to activate,
          // otherwise the primary actions are unreachable without a pointer.
          shortcuts: widget.onTap == null
              ? const <ShortcutActivator, Intent>{}
              : const {
                  SingleActivator(LogicalKeyboardKey.enter): _ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.space): _ActivateIntent(),
                },
          actions: widget.onTap == null
              ? const <Type, Action<Intent>>{}
              : {
                  _ActivateIntent: CallbackAction<_ActivateIntent>(
                    onInvoke: (_) {
                      widget.onTap?.call();
                      return null;
                    },
                  ),
                },
          onShowFocusHighlight: (value) {
            if (mounted) setState(() => _hasFocus = value);
          },
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Activates a [SpringButton] from the keyboard or a switch device.
class _ActivateIntent extends Intent {
  const _ActivateIntent();
}
