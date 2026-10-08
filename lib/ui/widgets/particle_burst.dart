import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Particle Model
// ---------------------------------------------------------------------------
class _Particle {
  late Offset position;
  late Offset velocity;
  late Color color;
  late double size;
  late double opacity;
  late double rotation;
  late double rotationSpeed;

  _Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
  });
}

// ---------------------------------------------------------------------------
// Particle Burst Widget — celebration confetti on "I Stood Up!"
// ---------------------------------------------------------------------------
class ParticleBurst extends StatefulWidget {
  final Color accentColor;
  final bool trigger;
  final Widget child;

  const ParticleBurst({
    super.key,
    required this.accentColor,
    required this.trigger,
    required this.child,
  });

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();
  bool _prevTrigger = false;
  DateTime? _lastFrame;

  static const _kParticleCount = 40;
  static const _kColors = [
    Color(0xFF10B981), // emerald
    Color(0xFF34D399),
    Color(0xFFFBBF24), // amber
    Color(0xFF60A5FA), // blue
    Color(0xFFF472B6), // pink
    Color(0xFFA78BFA), // purple
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )..addListener(() {
          setState(() => _updateParticles());
        });
  }

  @override
  void didUpdateWidget(ParticleBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger && !_prevTrigger) {
      _spawnParticles();
      _controller.forward(from: 0);
    }
    _prevTrigger = widget.trigger;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnParticles() {
    _particles.clear();
    _lastFrame = null;
    for (int i = 0; i < _kParticleCount; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 80 + _rng.nextDouble() * 220;
      _particles.add(
        _Particle(
          position: Offset.zero,
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          color: _kColors[_rng.nextInt(_kColors.length)],
          size: 4 + _rng.nextDouble() * 8,
          opacity: 1.0,
          rotation: _rng.nextDouble() * 2 * math.pi,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 8,
        ),
      );
    }
  }

  void _updateParticles() {
    final t = _controller.value;
    // Real elapsed time keeps the burst identical on 60 Hz and 120 Hz displays;
    // a fixed delta would double the particle speed on faster screens.
    final now = DateTime.now();
    final dt = _lastFrame == null
        ? 1 / 60
        : ((now.difference(_lastFrame!).inMicroseconds) / 1e6).clamp(0.0, 0.05);
    _lastFrame = now;

    for (final p in _particles) {
      p.position = Offset(
        p.position.dx + p.velocity.dx * dt,
        p.position.dy + p.velocity.dy * dt + 120 * dt * dt, // gravity
      );
      p.velocity = p.velocity * math.pow(0.97, dt * 60).toDouble();
      p.rotation += p.rotationSpeed * dt;
      p.opacity = (1.0 - t * 1.2).clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A 40-particle burst is the most motion in the app and fires on every
    // completed break. Honour the platform reduced-motion signal: the
    // celebration still happens, just without the confetti.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) return widget.child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ParticlePainter(particles: _particles),
              ),
            ),
          ),
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(center.dx + p.position.dx, center.dy + p.position.dy);
      canvas.rotate(p.rotation);

      // Draw as rounded square
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}
