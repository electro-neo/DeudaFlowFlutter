import 'package:flutter/material.dart';

class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  final Duration duration;

  const ScaleOnTap({
    Key? key,
    required this.child,
    required this.onTap,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 120),
  }) : super(key: key);

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
      lowerBound: widget.scale,
      upperBound: 1.0,
    );
    _animation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.forward();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(scale: _animation.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
