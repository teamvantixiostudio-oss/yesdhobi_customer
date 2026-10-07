import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum LogoVariant {
  navy,
  white,
}

/// The official Yes Dhobi vector brand logotype.
/// Renders the exact brand identity featuring the signature turquoise wave 'o'
/// and droplet 'i' with vector precision.
class YesDhobiLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final LogoVariant variant;
  final BoxFit fit;

  const YesDhobiLogo({
    super.key,
    this.width,
    this.height = 36.0,
    this.variant = LogoVariant.navy,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = variant == LogoVariant.white
        ? 'assets/images/yes_dhobi_logo_white.svg'
        : 'assets/images/yes_dhobi_logo.svg';

    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
    );
  }
}

/// Standalone Yes Dhobi Icon Mark / Emblem featuring the iconic
/// turquoise wave swirl & water droplet in an isolated vector painter.
class YesDhobiEmblemMark extends StatelessWidget {
  final double size;
  final Color waveColor;
  final Color dropColor;

  const YesDhobiEmblemMark({
    super.key,
    this.size = 56.0,
    this.waveColor = const Color(0xFF00D2B4),
    this.dropColor = const Color(0xFF0A0944),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _YesDhobiEmblemPainter(
          waveColor: waveColor,
          dropColor: dropColor,
        ),
      ),
    );
  }
}

class _YesDhobiEmblemPainter extends CustomPainter {
  final Color waveColor;
  final Color dropColor;

  _YesDhobiEmblemPainter({
    required this.waveColor,
    required this.dropColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Exact vector coordinates extracted from yes-dhobi-logo.svg
    // Center point of the 'o' is at (337.85, 75.40), radius ~ 27
    // Droplet is at (447, 24.5)
    // We compose them into a normalized canvas (0..100)
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Center circular wave 'o'
    final wavePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    // Outer ring with inner hole
    final outerPath = Path();
    outerPath.addOval(Rect.fromCircle(center: const Offset(48, 54), radius: 32));
    final innerPath = Path();
    innerPath.addOval(Rect.fromCircle(center: const Offset(48, 54), radius: 18));
    final ringPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(ringPath, wavePaint);

    // Dynamic swirl wave inside the 'o'
    final swirlPath = Path();
    swirlPath.moveTo(34, 54);
    swirlPath.cubicTo(35, 42, 42, 38, 51, 38);
    swirlPath.cubicTo(60, 38, 64, 44, 63, 50);
    swirlPath.cubicTo(62, 55, 57, 57, 52, 54);
    swirlPath.cubicTo(48, 51, 47, 47, 50, 44);
    swirlPath.cubicTo(51, 43, 50, 42, 48, 42);
    swirlPath.cubicTo(42, 43, 38, 48, 38, 54);
    swirlPath.close();
    canvas.drawPath(swirlPath, wavePaint);

    // Water droplet on top right
    final dropPaint = Paint()
      ..color = dropColor
      ..style = PaintingStyle.fill;

    final dropletPath = Path();
    dropletPath.moveTo(76, 26);
    dropletPath.cubicTo(74, 21, 68, 14, 68, 8);
    dropletPath.cubicTo(68, 2, 73, -1, 78, -1);
    dropletPath.cubicTo(83, -1, 87, 2, 87, 8);
    dropletPath.cubicTo(87, 15, 78, 22, 76, 26);
    dropletPath.close();
    canvas.drawPath(dropletPath, dropPaint);

    // Droplet white shine highlight
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final shinePath = Path();
    shinePath.moveTo(73, 8);
    shinePath.cubicTo(73, 4, 75, 1.5, 78, 1);
    canvas.drawPath(shinePath, shinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _YesDhobiEmblemPainter oldDelegate) =>
      oldDelegate.waveColor != waveColor || oldDelegate.dropColor != dropColor;
}

/// Ultra-Premium Floating Emblem Badge for the Hero Splash Screen
class YesDhobiSplashLogo extends StatelessWidget {
  final double size;

  const YesDhobiSplashLogo({super.key, this.size = 110.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          // Ambient colored aura glow
          BoxShadow(
            color: const Color(0xFF00D2B4).withValues(alpha: 0.35),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          // Deep elevation shadow
          BoxShadow(
            color: const Color(0xFF0A0944).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner frosted shimmer gradient
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF0FDF9),
                ],
              ),
              borderRadius: BorderRadius.circular(size * 0.26),
              border: Border.all(
                color: const Color(0xFF00D2B4).withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Center(
              child: YesDhobiEmblemMark(
                size: size * 0.52,
                waveColor: const Color(0xFF00D2B4),
                dropColor: const Color(0xFF0A0944),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini App Header Badge with the official Yes Dhobi wave emblem
class YesDhobiAppBadge extends StatelessWidget {
  final double size;

  const YesDhobiAppBadge({super.key, this.size = 28.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0944),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2B4).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: YesDhobiEmblemMark(
          size: size * 0.65,
          waveColor: const Color(0xFF00D2B4),
          dropColor: Colors.white,
        ),
      ),
    );
  }
}
