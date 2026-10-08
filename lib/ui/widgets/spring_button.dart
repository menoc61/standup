import 'package:flutter/material.dart';
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
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

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
              border: widget.border,
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: bg.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
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
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}
