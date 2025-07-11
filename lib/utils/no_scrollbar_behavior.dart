import 'package:flutter/material.dart';

/// Utilidad global para ocultar el scrollbar en cualquier ScrollConfiguration
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
