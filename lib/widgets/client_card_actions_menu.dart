import 'package:flutter/material.dart';

class ClientCardActionsMenu extends StatefulWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onViewMovements;
  final VoidCallback? onReceipt;
  const ClientCardActionsMenu({
    super.key,
    this.onEdit,
    this.onDelete,
    this.onAddTransaction,
    this.onViewMovements,
    this.onReceipt,
  });

  @override
  State<ClientCardActionsMenu> createState() => _ClientCardActionsMenuState();
}

class _ClientCardActionsMenuState extends State<ClientCardActionsMenu> {
  void _showMenu(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 40, 16, 0),
      items: [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Recibo'),
            onTap: () {
              Navigator.pop(context);
              widget.onReceipt?.call();
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(context);
              widget.onEdit?.call();
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Eliminar'),
            onTap: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Agregar deuda/abono'),
            onTap: () {
              Navigator.pop(context);
              widget.onAddTransaction?.call();
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Ver movimientos'),
            onTap: () {
              Navigator.pop(context);
              widget.onViewMovements?.call();
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Acciones',
      onPressed: () => _showMenu(context),
    );
  }
}
