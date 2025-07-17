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
        const double moveY = 100;
        if (isAnimating) {
          if (index == 0) {
            // El primer item se va desvaneciendo y subiendo
            opacity = 1.0 - animation.value;
            offsetY = -moveY * animation.value;
          } else if (index == itemCount - 1) {
            // El último item aparece desde abajo
            opacity = minOpacity + (1.0 - minOpacity) * animation.value;
            offsetY = moveY * (1 - animation.value);
          } else {
            // Los demás suben en sincronía
            offsetY = -moveY * animation.value;
          }
        }
        if (index > 0) {
          final fade =
              (1 - (index / (itemCount - 1)).clamp(0, 1)) * (1 - minOpacity) +
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
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
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
      // Espera un poco antes de resetear para que el fade-out termine visualmente
      await Future.delayed(const Duration(milliseconds: 300));
      _controller.reset();
    });
  }

  @override
  void didUpdateWidget(covariant CyclicAnimatedFadeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Actualiza los items si los hijos cambiaron (no solo la longitud)
    final newChildren = widget.children;
    bool needsUpdate = false;
    if (newChildren.length != _items.length) {
      needsUpdate = true;
    } else {
      for (int i = 0; i < newChildren.length; i++) {
        if (newChildren[i].key != _items[i].key || newChildren[i] != _items[i]) {
          needsUpdate = true;
          break;
        }
      }
    }
    if (needsUpdate) {
      _items = List<Widget>.from(newChildren);
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
      );
      _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _items.length,
      itemBuilder: (context, i) {
        return _AnimatedFadeListItem(
          index: i,
          isAnimating: _isAnimating,
          animation: _animation,
          itemCount: _items.length,
          minOpacity: widget.minOpacity,
          itemSpacing: widget.itemSpacing,
          child: _items[i],
        );
      },
    );
  }
}
