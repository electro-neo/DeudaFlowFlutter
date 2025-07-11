import 'dart:async';
import 'package:flutter/material.dart';

/// Lista animada cíclica: el primer elemento sube, se desvanece y reaparece abajo.
class CyclicAnimatedFadeList extends StatefulWidget {
  final List<Widget> children;
  final Duration interval;
  final Duration animationDuration;
  final double minOpacity;
  final double itemSpacing;

  const CyclicAnimatedFadeList({
    super.key,
    required this.children,
    this.interval = const Duration(seconds: 2),
    this.animationDuration = const Duration(milliseconds: 700),
    this.minOpacity = 0.25,
    this.itemSpacing = 10.0,
  });

  @override
  State<CyclicAnimatedFadeList> createState() => _CyclicAnimatedFadeListState();
}

class _AnimatedFadeListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final bool isAnimating;
  final Animation<double> animation;
  final int itemCount;
  final double minOpacity;
  final double itemSpacing;

  const _AnimatedFadeListItem({
    required this.child,
    required this.index,
    required this.isAnimating,
    required this.animation,
    required this.itemCount,
    required this.minOpacity,
    required this.itemSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        double opacity = 1.0;
        double offsetY = 0.0;
        if (index == 0 && isAnimating) {
          opacity = 1.0 - animation.value;
          offsetY = -30 * animation.value;
        } else if (index == 1 && isAnimating) {
          offsetY = -30 * (1 - animation.value);
        }
        if (index > 0) {
          final fade =
              (1 - (index / (itemCount - 1)).clamp(0, 1)) *
                  (1 - minOpacity) +
              minOpacity;
          opacity *= fade;
        }
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index == itemCount - 1 ? 0 : itemSpacing,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _CyclicAnimatedFadeListState extends State<CyclicAnimatedFadeList>
    with SingleTickerProviderStateMixin {
  late List<Widget> _items;
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _timer;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _items = List<Widget>.from(widget.children);
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _startCycle();
  }

  void _startCycle() {
    _timer = Timer.periodic(widget.interval, (_) async {
      if (_isAnimating || _items.length < 2) return;
      setState(() => _isAnimating = true);
      await _controller.forward(from: 0);
      setState(() {
        final first = _items.removeAt(0);
        _items.add(first);
        _isAnimating = false;
      });
      _controller.reset();
    });
  }

  @override
  void didUpdateWidget(covariant CyclicAnimatedFadeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update items if children changed
    if (widget.children.length != _items.length) {
      _items = List<Widget>.from(widget.children);
    }
    // Restart timer if interval changed
    if (widget.interval != oldWidget.interval) {
      _timer?.cancel();
      _startCycle();
    }
    // Update animation controller if animationDuration changed
    if (widget.animationDuration != oldWidget.animationDuration) {
      _controller.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: widget.animationDuration,
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _items.length,
      itemBuilder: (context, i) {
        return _AnimatedFadeListItem(
          child: _items[i],
          index: i,
          isAnimating: _isAnimating,
          animation: _animation,
          itemCount: _items.length,
          minOpacity: widget.minOpacity,
          itemSpacing: widget.itemSpacing,
        );
      },
    );
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: i == _items.length - 1 ? 0 : widget.itemSpacing,
                  ),
                  child: _items[i],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
