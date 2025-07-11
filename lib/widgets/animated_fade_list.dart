import 'package:flutter/material.dart';

class AnimatedFadeList extends StatelessWidget {
  final List<Widget> children;
  final double fadeFraction;
  final double minOpacity;
  final Duration duration;
  final Curve curve;
  final double itemSpacing;

  const AnimatedFadeList({
    super.key,
    required this.children,
    this.fadeFraction = 0.5,
    this.minOpacity = 0.25,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOut,
    this.itemSpacing = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, animValue, child) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          itemBuilder: (context, i) {
            return _AnimatedFadeListItem(
            final denominator = (children.length - 1) == 0 ? 1 : (children.length - 1);
            final fade =
                (1 - (i / denominator).clamp(0, 1)) *
                    (1 - minOpacity) +
                minOpacity;
            final opacity =
                fadeFraction + (1 - fadeFraction) * animValue * fade;
            final offsetY = (1 - animValue) * 30 * (i / denominator);
            );
          },
        );
      },
    );
  }
  
  class _AnimatedFadeListItem extends StatelessWidget {
    final int index;
    final int total;
    final double fadeFraction;
    final double minOpacity;
    final double animValue;
    final double itemSpacing;
    final Widget child;
  
    const _AnimatedFadeListItem({
      required this.index,
      required this.total,
      required this.fadeFraction,
      required this.minOpacity,
      required this.animValue,
      required this.itemSpacing,
      required this.child,
    });
  
    @override
    Widget build(BuildContext context) {
      final fade =
          (1 - (index / (total - 1)).clamp(0, 1)) * (1 - minOpacity) + minOpacity;
      final opacity = fadeFraction + (1 - fadeFraction) * animValue * fade;
      final offsetY = (1 - animValue) * 30 * (index / (total - 1));
      return Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, offsetY),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index == total - 1 ? 0 : itemSpacing,
            ),
            child: child,
          ),
        ),
      );
    }
  }
}
