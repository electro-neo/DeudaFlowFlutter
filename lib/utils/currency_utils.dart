import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/currency_provider.dart';

/// Utilidad para convertir y formatear montos según la moneda seleccionada.
class CurrencyUtils {
  static double convert(BuildContext context, num value) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final isUSD = currencyProvider.currency == 'USD';
    final rate = currencyProvider.rate > 0 ? currencyProvider.rate : 1.0;
    return isUSD ? value.toDouble() / rate : value.toDouble();
  }

  static String symbol(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    return currencyProvider.currency == 'USD' ? '\$' : '';
  }

  static String format(BuildContext context, num value) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final isUSD = currencyProvider.currency == 'USD';
    final rate = currencyProvider.rate > 0 ? currencyProvider.rate : 1.0;
    // Si es USD, no dividir ni modificar el valor
    final converted = isUSD ? value.toDouble() : value.toDouble();
    final formatter = NumberFormat.currency(
      locale: 'es',
      symbol: isUSD ? '\$' : '',
      decimalDigits: 2,
      customPattern: '#,##0.00',
    );
    return formatter.format(converted);
  }

  static String formatCompact(BuildContext context, num value) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final isUSD = currencyProvider.currency == 'USD';
    final rate = currencyProvider.rate > 0 ? currencyProvider.rate : 1.0;
    final converted = isUSD ? value.toDouble() / rate : value.toDouble();
    final compact = NumberFormat.compact(locale: 'en').format(converted);
    return isUSD ? '\$$compact' : compact;
  }
}
