import 'package:flutter/material.dart';

class FaqHelpSheet extends StatelessWidget {
  const FaqHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Ayuda / FAQ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Párrafo introductorio de funcionalidades
            const Text(
              'Deuda Flow te permite gestionar de forma sencilla y segura tus deudas y abonos con clientes. Registra movimientos, consulta balances, genera recibos, sincroniza datos y mantén el control de tus finanzas o de tu negocio. Usa los botones y secciones para navegar, agregar, editar y compartir información de manera intuitiva.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Sección Moneda:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(
                Icons.attach_money_rounded,
                color: Colors.indigo,
              ),
              title: const Text('Toggle USD:'),
              subtitle: const Text(
                'Los montos en moneda local pueden convertirse a USD según la tasa que definas en la app.',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sección Clientes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.indigo),
              title: const Text('Registrar Cliente: Crea un nuevo cliente.'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.indigo),
              title: const Text(
                'Recibo general: Genera un recibo de todos los clientes.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.indigo),
              title: const Text(
                'Sincronizar: Actualiza clientes y transacciones.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.indigo),
              title: const Text(
                'Buscar: Muestra el campo de búsqueda de clientes.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Eliminar TODOS: Borra todos los clientes y transacciones.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.indigo),
              title: const Text(
                'Agregar transacción: Añade una transacción a un cliente.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt, color: Colors.indigo),
              title: const Text(
                'Recibo individual: Genera recibo de un cliente.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.indigo),
              title: const Text(
                'Editar cliente: Modifica los datos del cliente.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar cliente: Borra un cliente.'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sección Transacciones:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.indigo),
              title: const Text('Calendario: Filtra transacciones por fecha.'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar transacción: Desliza a la izquierda para borrar.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.filter_alt_off, color: Colors.indigo),
              title: const Text(
                'Borrar filtro de fecha: Limpia el filtro de fechas.',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Formularios y Modales:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.save, color: Colors.indigo),
              title: const Text('Guardar: Guarda los datos ingresados.'),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.indigo),
              title: const Text(
                'Cerrar/Cancelar: Cierra el formulario o modal.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.indigo),
              title: const Text(
                'Compartir recibo: Envía o comparte un recibo.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.indigo),
              title: const Text('Imprimir recibo: Imprime un recibo.'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Barra de navegación y menú:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.indigo),
              title: const Text('Dashboard: Vista principal de la app.'),
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.indigo),
              title: const Text('Clientes: Acceso a la lista de clientes.'),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.indigo),
              title: const Text(
                'Movimientos: Acceso a la lista de transacciones.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.menu, color: Colors.indigo),
              title: const Text('Menú: Acceso a opciones y configuración.'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar sesión: Salir de la aplicación.'),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cerrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[50],
                  foregroundColor: Colors.indigo,
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
