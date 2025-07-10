import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/client_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/tab_provider.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/currency_provider.dart';
import '../utils/currency_utils.dart';

class DashboardStats extends StatelessWidget {
  const DashboardStats({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de moneda/tasa
    context.watch<CurrencyProvider>();
    final clients = context.watch<ClientProvider>().clients;
    final transactions = context.watch<TransactionProvider>().transactions;
    final totalClients = clients.length;
    String format(num value) => CurrencyUtils.formatCompact(context, value);
    final totalDeuda = clients.fold<double>(
      0,
      (sum, c) => sum + (c.balance < 0 ? -c.balance : 0),
    );
    final totalAbonado = transactions
        .where((t) => t.type == 'payment')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalSaldo = clients.fold<double>(0, (sum, c) => sum + c.balance);
    // Navegación igual que el botón de la barra inferior usando Provider
    void goToClientsTab() {
      Provider.of<TabProvider>(context, listen: false).setTab(1);
    }

    void goToDeudaTab() {
      Provider.of<TransactionFilterProvider>(
        context,
        listen: false,
      ).setType('debt');
      Provider.of<TabProvider>(context, listen: false).setTab(2);
    }

    void goToAbonoTab() {
      Provider.of<TransactionFilterProvider>(
        context,
        listen: false,
      ).setType('payment');
      Provider.of<TabProvider>(context, listen: false).setTab(2);
    }

    // Creamos los stat cards
    final statClientes = _StatCard(
      label: 'Clientes',
      value: totalClients.toString(),
      icon: Icons.people,
      isButton: true,
      onTap: goToClientsTab,
    );
    final statDeuda = _StatCard(
      label: 'Deuda total',
      value: format(totalDeuda),
      icon: Icons.trending_up,
      color: Colors.red,
      isButton: true,
      onTap: goToDeudaTab,
    );
    final statAbonado = _StatCard(
      label: 'Total abonado',
      value: format(totalAbonado),
      icon: Icons.trending_down,
      color: Colors.green,
      isButton: true,
      onTap: goToAbonoTab,
    );
    String saldoLabel;
    if (totalSaldo < 0) {
      saldoLabel = 'Saldo a recibir';
    } else if (totalSaldo > 0) {
      saldoLabel = 'Saldo a entregar';
    } else {
      saldoLabel = 'Sin movimientos';
    }
    final statSaldo = _StatCard(
      label: saldoLabel,
      value: format(totalSaldo),
      icon: Icons.account_balance_wallet,
    );

    // Orden personalizado: Clientes y Saldo neto arriba, Deuda total y Total abonado abajo
    return Center(
      child: SizedBox(
        width: 600,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: statClientes),
                const SizedBox(width: 16),
                Expanded(child: statSaldo),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: statDeuda),
                const SizedBox(width: 16),
                Expanded(child: statAbonado),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool isButton;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.isButton = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardColor = isLight ? Colors.white : null;
    final cardContent = Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.blue, size: 32),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
    if (isButton) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: cardColor,
          child: cardContent,
        ),
      );
    } else {
      return Card(color: cardColor, child: cardContent);
    }
  }
}
