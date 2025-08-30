import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';

class DuggyLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showText;
  final bool animated;

  const DuggyLogo({
    super.key,
    this.size = 64.0,
    this.color,
    this.showText = false,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? AppTheme.primaryBlue;

    if (animated) {
      return _AnimatedDuggyLogo(
        size: size,
        color: logoColor,
        showText: showText,
      );
    }

    return _StaticDuggyLogo(size: size, color: logoColor, showText: showText);
  }
}

class _StaticDuggyLogo extends StatelessWidget {
  final double size;
  final Color color;
  final bool showText;

  const _StaticDuggyLogo({
    required this.size,
    required this.color,
    required this.showText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: size * 0.2,
                offset: Offset(0, size * 0.1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.1),
            child: SvgPicture.asset(
              'assets/images/duggy_logo.svg',
              width: size,
              height: size,
              fit: BoxFit.contain,
              colorFilter: color != AppTheme.primaryBlue
                  ? ColorFilter.mode(color, BlendMode.srcIn)
                  : null,
            ),
          ),
        ),

        if (showText) ...[
          SizedBox(height: size * 0.2),
          Text(
            'DUGGY',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: size * 0.02,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnimatedDuggyLogo extends StatefulWidget {
  final double size;
  final Color color;
  final bool showText;

  const _AnimatedDuggyLogo({
    required this.size,
    required this.color,
    required this.showText,
  });

  @override
  State<_AnimatedDuggyLogo> createState() => _AnimatedDuggyLogoState();
}

class _AnimatedDuggyLogoState extends State<_AnimatedDuggyLogo>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start animations in sequence
    _scaleController.forward().then((_) {
      _fadeController.forward();
      _rotationController.repeat();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationController,
        _scaleController,
        _fadeController,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Transform.rotate(
              angle: _rotationAnimation.value * 0.1, // Subtle rotation
              child: _StaticDuggyLogo(
                size: widget.size,
                color: widget.color,
                showText: widget.showText,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DuggyBackgroundPainter extends CustomPainter {
  final Color color;

  _DuggyBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw subtle cricket field pattern
    final center = Offset(size.width / 2, size.height / 2);

    // Wicket lines
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        (size.width * 0.15) + (i * size.width * 0.1),
        paint
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // Cricket pitch rectangle
    final rect = RRect.fromLTRBR(
      size.width * 0.3,
      size.height * 0.25,
      size.width * 0.7,
      size.height * 0.75,
      Radius.circular(size.width * 0.05),
    );
    canvas.drawRRect(rect, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Logo variants for different use cases
class DuggyLogoVariant {
  static Widget small({Color? color}) => DuggyLogo(size: 32, color: color);

  static Widget medium({Color? color, bool showText = false}) =>
      DuggyLogo(size: 64, color: color, showText: showText);

  static Widget large({Color? color, bool showText = true}) =>
      DuggyLogo(size: 128, color: color, showText: showText);

  static Widget animated({
    double size = 100,
    Color? color,
    bool showText = false,
  }) => DuggyLogo(size: size, color: color, showText: showText, animated: true);

  // Special variant for splash screen
  static Widget splash() =>
      DuggyLogo(size: 150, color: Colors.white, showText: true, animated: true);

  // Monochrome variant for certain contexts
  static Widget monochrome({double size = 64, bool showText = false}) =>
      Container(
        width: size,
        height: showText ? size * 1.5 : size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              child: SvgPicture.asset(
                'assets/images/duggy_logo.svg',
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
            if (showText) ...[
              SizedBox(height: size * 0.15),
              Text(
                'DUGGY',
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: size * 0.01,
                ),
              ),
            ],
          ],
        ),
      );
}
