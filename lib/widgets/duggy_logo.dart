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
    final logoColor = color ?? Theme.of(context).colorScheme.primary;

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
        SvgPicture.asset(
          'assets/images/duggy_logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),

        if (showText) ...[
          SizedBox(height: size * 0.2),
          Text(
            'DUGGY',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.w600,
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

// Logo variants for different use cases
class DuggyLogoVariant {
  static Widget small({Color? color}) => DuggyLogo(size: 42, color: color);

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
  static Widget splash(BuildContext context) =>
      DuggyLogo(size: 150, showText: true, animated: true);

  // Monochrome variant for certain contexts
  static Widget monochrome({double size = 64, bool showText = false}) =>
      SizedBox(
        width: size,
        height: showText ? size * 1.5 : size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
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
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.primaryTextColor,
                  letterSpacing: size * 0.01,
                ),
              ),
            ],
          ],
        ),
      );
}
