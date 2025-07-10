import 'package:flutter/material.dart';

class ClientCardActionsFAB extends StatefulWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onViewMovements;
  final VoidCallback? onReceipt;
  const ClientCardActionsFAB({
    super.key,
    this.onEdit,
    this.onDelete,
    this.onAddTransaction,
    this.onViewMovements,
    this.onReceipt,
  });

  @override
  State<ClientCardActionsFAB> createState() => _ClientCardActionsFABState();
}

class _ClientCardActionsFABState extends State<ClientCardActionsFAB>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Widget _buildAction(
    IconData icon,
    String tooltip,
    VoidCallback? onTap,
    int index,
  ) {
    return AnimatedScale(
      scale: _open ? 1 : 0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _open ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FloatingActionButton(
            heroTag: tooltip,
            mini: true,
            onPressed: () {
              onTap?.call();
              _toggle();
            },
            tooltip: tooltip,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      [Icons.list, 'Ver movimientos', widget.onViewMovements],
      [Icons.add, 'Agregar deuda/abono', widget.onAddTransaction],
      [Icons.delete, 'Eliminar', widget.onDelete],
      [Icons.edit, 'Editar', widget.onEdit],
      [Icons.receipt_long, 'Recibo', widget.onReceipt],
    ];
    return SizedBox(
      height: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _open ? 48 : 0,
            curve: Curves.easeOut,
            child: _open
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < actions.length; i++)
                        _buildAction(
                          actions[i][0] as IconData,
                          actions[i][1] as String,
                          actions[i][2] as VoidCallback?,
                          i,
                        ),
                    ],
                  )
                : null,
          ),
          FloatingActionButton(
            heroTag: 'menu',
            onPressed: _toggle,
            tooltip: 'Acciones',
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _controller,
            ),
          ),
        ],
      ),
    );
  }
}
