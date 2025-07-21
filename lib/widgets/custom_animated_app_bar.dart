import 'package:flutter/material.dart';

class CustomAnimatedAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  final String title;
  final double height;
  final VoidCallback? onMenuTap;

  const CustomAnimatedAppBar({
    super.key,
    required this.title,
    this.height = 80,
    this.onMenuTap,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  State<CustomAnimatedAppBar> createState() => CustomAnimatedAppBarState();
}

class CustomAnimatedAppBarState extends State<CustomAnimatedAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _colorAnimationController;
  late Animation<Color?> _backgroundColorTween;
  late Animation<Color?> _iconColorTween;
  late Animation<Color?> _textColorTween;

  @override
  void initState() {
    super.initState();
    _colorAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _backgroundColorTween = ColorTween(
      begin: Colors.blue.shade700,
      end: Colors.white,
    ).animate(_colorAnimationController);
    _iconColorTween = ColorTween(
      begin: Colors.white,
      end: Colors.blue.shade700,
    ).animate(_colorAnimationController);
    _textColorTween = ColorTween(
      begin: Colors.white,
      end: Colors.blue.shade700,
    ).animate(_colorAnimationController);
  }

  void animateAppBar(bool scrolled) {
    if (scrolled) {
      _colorAnimationController.forward();
    } else {
      _colorAnimationController.reverse();
    }
  }

  @override
  void dispose() {
    _colorAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimationController,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: _backgroundColorTween.value,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  red: ((Colors.black.r * 255.0).round() & 0xff).toDouble(),
                  green: ((Colors.black.g * 255.0).round() & 0xff).toDouble(),
                  blue: ((Colors.black.b * 255.0).round() & 0xff).toDouble(),
                  alpha: 0.15 * 255,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.menu, color: _iconColorTween.value, size: 28),
                onPressed: widget.onMenuTap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: _textColorTween.value,
                    letterSpacing: 1.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(
                          red: ((Colors.black.r * 255.0).round() & 0xff)
                              .toDouble(),
                          green: ((Colors.black.g * 255.0).round() & 0xff)
                              .toDouble(),
                          blue: ((Colors.black.b * 255.0).round() & 0xff)
                              .toDouble(),
                          alpha: 0.08 * 255,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Espacio para simetría visual
            ],
          ),
        );
      },
    );
  }
}
