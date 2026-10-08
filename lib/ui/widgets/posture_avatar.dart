import 'dart:math' as math;

import 'package:flutter/material.dart';

const _illustrationInk = Color(0xFF263D31);

class PostureAvatar extends StatefulWidget {
  final bool isStanding;
  final double stretchProgress;
  final Color accentColor;
  final double size;

  const PostureAvatar({
    super.key,
    required this.isStanding,
    this.stretchProgress = 0.0,
    required this.accentColor,
    this.size = 200,
  });

  @override
  State<PostureAvatar> createState() => _PostureAvatarState();
}

class _PostureAvatarState extends State<PostureAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _breatheController.isAnimating) {
      _breatheController.stop();
    } else if (!reduceMotion && !_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
    }

    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PostureCharacterPainter(
            isStanding: widget.isStanding,
            stretchProgress: widget.stretchProgress,
            breatheValue: _breatheController.value,
            accentColor: widget.accentColor,
          ),
        );
      },
    );
  }
}

class _PostureCharacterPainter extends CustomPainter {
  final bool isStanding;
  final double stretchProgress;
  final double breatheValue;
  final Color accentColor;

  _PostureCharacterPainter({
    required this.isStanding,
    required this.stretchProgress,
    required this.breatheValue,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 240;
    canvas.save();
    canvas.translate(
      (size.width - 240 * scale) / 2,
      (size.height - 240 * scale) / 2,
    );
    canvas.scale(scale);

    const ink = _illustrationInk;
    const skin = Color(0xFFD79A73);
    const hair = Color(0xFF4E4539);
    const trousers = Color(0xFF526A61);
    const wood = Color(0xFFB68B5B);
    const paper = Color(0xFFF7F2E8);
    const slate = Color(0xFF3F5C50);
    final breath = math.sin(breatheValue * math.pi) * 1.8;

    // A warm, calm studio field, with depth that stays legible at small sizes.
    canvas.drawCircle(
      const Offset(120, 120),
      112,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                paper,
                accentColor.withValues(alpha: 0.14),
                accentColor.withValues(alpha: 0.045),
              ],
              stops: const [0, .72, 1],
            ).createShader(
              Rect.fromCircle(center: const Offset(120, 120), radius: 112),
            ),
    );
    canvas.drawCircle(
      const Offset(120, 120),
      100,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawOval(
      const Rect.fromLTWH(55, 196, 130, 17),
      Paint()..color = ink.withValues(alpha: 0.11),
    );

    _drawPlant(canvas, accentColor, ink);
    if (isStanding) {
      _drawStandingFigure(canvas, accentColor, skin, hair, trousers, breath);
    } else {
      _drawSeatedFigure(
        canvas,
        accentColor,
        skin,
        hair,
        trousers,
        wood,
        slate,
        breath,
      );
    }

    canvas.restore();
  }

  void _drawPlant(Canvas canvas, Color leaf, Color stem) {
    final stemPaint = Paint()
      ..color = stem.withValues(alpha: .5)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final leafPaint = Paint()..color = leaf.withValues(alpha: .62);
    canvas.drawLine(const Offset(185, 185), const Offset(188, 125), stemPaint);
    for (final leaf in <(Offset, Offset, double)>[
      (const Offset(188, 151), const Offset(174, 142), -0.2),
      (const Offset(188, 145), const Offset(201, 134), 0.2),
      (const Offset(187, 163), const Offset(173, 157), -0.12),
      (const Offset(188, 158), const Offset(202, 151), 0.14),
    ]) {
      canvas.save();
      canvas.translate(leaf.$1.dx, leaf.$1.dy);
      canvas.rotate(leaf.$3);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(12, -11, 19, -2)
        ..quadraticBezierTo(11, 8, 0, 0);
      canvas.drawPath(path, leafPaint);
      canvas.restore();
      canvas.drawLine(leaf.$1, leaf.$2, stemPaint);
    }
    final pot = RRect.fromRectAndRadius(
      const Rect.fromLTWH(178, 180, 20, 19),
      const Radius.circular(5),
    );
    canvas.drawRRect(pot, Paint()..color = const Color(0xFFC99267));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(176, 178, 24, 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFB9825D),
    );
  }

  void _drawStandingFigure(
    Canvas canvas,
    Color shirt,
    Color skin,
    Color hair,
    Color trousers,
    double breath,
  ) {
    final lift = stretchProgress.clamp(0.0, 1.0);
    final headY = 57 - breath - lift * 4;
    final leftElbow = Offset(83 - lift * 9, 70 - lift * 13);
    final rightElbow = Offset(157 + lift * 9, 70 - lift * 13);
    final leftHand = Offset(75 - lift * 15, 47 - lift * 20);
    final rightHand = Offset(165 + lift * 15, 47 - lift * 20);

    // Soft garment shadow and body shape.
    final torso = Path()
      ..moveTo(101, 82)
      ..quadraticBezierTo(120, 73, 139, 82)
      ..lineTo(151, 133)
      ..quadraticBezierTo(120, 146, 89, 133)
      ..close();
    canvas.drawPath(
      torso.shift(const Offset(0, 2)),
      Paint()..color = _illustrationInk.withValues(alpha: .12),
    );
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            shirt,
            shirt.withValues(alpha: .76),
            const Color(0xFF315644),
          ],
        ).createShader(const Rect.fromLTWH(88, 72, 64, 76)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(111, 81)
        ..quadraticBezierTo(120, 85, 129, 81)
        ..lineTo(120, 101)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .28),
    );

    _drawLimb(canvas, const Offset(104, 88), leftElbow, leftHand, skin, shirt);
    _drawLimb(
      canvas,
      const Offset(136, 88),
      rightElbow,
      rightHand,
      skin,
      shirt,
    );

    // Tailored trousers and shoes.
    _stroke(
      canvas,
      const Offset(106, 137),
      const Offset(105, 171),
      trousers,
      14,
    );
    _stroke(
      canvas,
      const Offset(134, 137),
      const Offset(135, 171),
      trousers,
      14,
    );
    _stroke(
      canvas,
      const Offset(105, 168),
      const Offset(101, 194),
      trousers,
      11,
    );
    _stroke(
      canvas,
      const Offset(135, 168),
      const Offset(139, 194),
      trousers,
      11,
    );
    _stroke(canvas, const Offset(101, 194), const Offset(88, 198), hair, 8);
    _stroke(canvas, const Offset(139, 194), const Offset(152, 198), hair, 8);

    _drawHead(canvas, Offset(120, headY), skin, hair);
    canvas.drawLine(
      Offset(120, 100 - lift * 3),
      Offset(120, 132),
      Paint()
        ..color = Colors.white.withValues(alpha: .22)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSeatedFigure(
    Canvas canvas,
    Color shirt,
    Color skin,
    Color hair,
    Color trousers,
    Color wood,
    Color device,
    double breath,
  ) {
    // Chair and quiet desk silhouette establish the workplace at a glance.
    final chair = Paint()
      ..color = const Color(0xFF8A8E7E).withValues(alpha: .7)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(166, 108), const Offset(166, 170), chair);
    canvas.drawLine(const Offset(146, 132), const Offset(176, 132), chair);
    canvas.drawLine(const Offset(151, 134), const Offset(145, 171), chair);
    canvas.drawLine(const Offset(173, 134), const Offset(180, 171), chair);

    final torso = Path()
      ..moveTo(118, 89 - breath)
      ..quadraticBezierTo(133, 83 - breath, 145, 95)
      ..lineTo(151, 133)
      ..quadraticBezierTo(129, 144, 110, 134)
      ..lineTo(112, 105)
      ..close();
    canvas.drawPath(torso, Paint()..color = shirt.withValues(alpha: .92));
    canvas.drawPath(
      Path()
        ..moveTo(122, 94)
        ..quadraticBezierTo(133, 102, 143, 96)
        ..lineTo(146, 127)
        ..quadraticBezierTo(133, 134, 117, 128)
        ..close(),
      Paint()..color = shirt.withValues(alpha: .7),
    );

    // Bent legs, desk plane, and a small open laptop.
    _stroke(
      canvas,
      const Offset(135, 135),
      const Offset(105, 151),
      trousers,
      13,
    );
    _stroke(
      canvas,
      const Offset(105, 151),
      const Offset(92, 183),
      trousers,
      11,
    );
    _stroke(
      canvas,
      const Offset(139, 135),
      const Offset(154, 156),
      trousers,
      13,
    );
    _stroke(
      canvas,
      const Offset(154, 156),
      const Offset(160, 182),
      trousers,
      11,
    );
    _stroke(canvas, const Offset(92, 183), const Offset(78, 185), hair, 7);
    _stroke(canvas, const Offset(160, 182), const Offset(172, 184), hair, 7);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 130, 123, 8),
        const Radius.circular(4),
      ),
      Paint()..color = wood,
    );
    canvas.drawLine(
      const Offset(63, 138),
      const Offset(60, 185),
      Paint()
        ..color = wood
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      const Offset(159, 138),
      const Offset(162, 184),
      Paint()
        ..color = wood
        ..strokeWidth = 4,
    );
    canvas.drawPath(
      Path()
        ..moveTo(74, 128)
        ..lineTo(79, 101)
        ..quadraticBezierTo(81, 97, 85, 99)
        ..lineTo(109, 104)
        ..lineTo(108, 128)
        ..close(),
      Paint()..color = device,
    );
    canvas.drawLine(
      const Offset(81, 105),
      const Offset(104, 110),
      Paint()
        ..color = Colors.white.withValues(alpha: .7)
        ..strokeWidth = 1.2,
    );

    // The shoulders angle inward and the hands reach toward the keyboard.
    _drawLimb(
      canvas,
      const Offset(119, 94),
      const Offset(103, 113),
      const Offset(87, 121),
      skin,
      shirt,
    );
    _drawLimb(
      canvas,
      const Offset(143, 96),
      const Offset(150, 114),
      const Offset(139, 124),
      skin,
      shirt,
    );

    final head = Offset(139, 70 - breath);
    _drawHead(canvas, head, skin, hair);
    canvas.drawLine(
      const Offset(117, 91),
      const Offset(132, 90),
      Paint()
        ..color = Colors.white.withValues(alpha: .24)
        ..strokeWidth = 1.2,
    );
  }

  void _drawLimb(
    Canvas canvas,
    Offset shoulder,
    Offset elbow,
    Offset hand,
    Color skin,
    Color sleeve,
  ) {
    _stroke(canvas, shoulder, elbow, sleeve, 13);
    _stroke(canvas, elbow, hand, skin, 8);
    canvas.drawCircle(elbow, 4.5, Paint()..color = skin);
    canvas.drawCircle(hand, 4.8, Paint()..color = skin);
  }

  void _drawHead(Canvas canvas, Offset center, Color skin, Color hair) {
    final head = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 25, height: 31),
      const Radius.circular(12),
    );
    canvas.drawRRect(head, Paint()..color = skin);
    final hairline = Path()
      ..moveTo(center.dx - 12, center.dy - 4)
      ..quadraticBezierTo(
        center.dx - 12,
        center.dy - 20,
        center.dx + 2,
        center.dy - 16,
      )
      ..quadraticBezierTo(
        center.dx + 15,
        center.dy - 15,
        center.dx + 12,
        center.dy - 2,
      )
      ..quadraticBezierTo(
        center.dx + 5,
        center.dy - 9,
        center.dx - 3,
        center.dy - 7,
      )
      ..quadraticBezierTo(
        center.dx - 8,
        center.dy - 6,
        center.dx - 12,
        center.dy - 4,
      )
      ..close();
    canvas.drawPath(hairline, Paint()..color = hair);
    canvas.drawCircle(
      Offset(center.dx + 6, center.dy + 1),
      1,
      Paint()..color = const Color(0xFF61453A).withValues(alpha: .6),
    );
  }

  void _stroke(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double width,
  ) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PostureCharacterPainter oldDelegate) {
    return oldDelegate.isStanding != isStanding ||
        oldDelegate.stretchProgress != stretchProgress ||
        oldDelegate.breatheValue != breatheValue ||
        oldDelegate.accentColor != accentColor;
  }
}
