import 'package:flutter/material.dart';

class AppNavigationBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final VoidCallback? onAddPressed;
  const AppNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.indigo[700],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.dashboard,
              color: currentIndex == 0 ? Colors.white : Colors.white70,
            ),
            onPressed: () => onTap(0),
            tooltip: 'Dashboard',
          ),
          IconButton(
            icon: Icon(
              Icons.people,
              color: currentIndex == 1 ? Colors.white : Colors.white70,
            ),
            onPressed: () => onTap(1),
            tooltip: 'Clientes',
          ),
          IconButton(
            icon: Icon(
              Icons.list_alt,
              color: currentIndex == 2 ? Colors.white : Colors.white70,
            ),
            onPressed: () => onTap(2),
            tooltip: 'Movimientos',
          ),
        ],
      ),
    );
  }
}
