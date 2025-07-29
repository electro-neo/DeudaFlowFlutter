import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/currency_provider.dart';

/// Utilidad para convertir y formatear montos según la moneda seleccionada.
class CurrencyUtils {
  /// Convierte de USD a la moneda seleccionada usando la tasa actual.
  /// Si la moneda es USD, retorna el valor tal cual.
  /// Si la moneda es otra, multiplica por la tasa.
  static double convert(BuildContext context, num value) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final isUSD = currencyProvider.currency == 'USD';
    final rate = currencyProvider.rate > 0 ? currencyProvider.rate : 1.0;
    return isUSD ? value.toDouble() : value.toDouble() * rate;
  }

  static String symbol(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    return currencyProvider.currency == 'USD' ? '\$' : '';
  }

  /// Formatea el valor recibido tal cual, solo aplica separadores y símbolo según la moneda indicada.
  /// No realiza ninguna conversión, asume que el valor ya está en la moneda correcta.
  static String format(BuildContext context, num value, {String? currencyCode}) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    // Permite forzar el símbolo según la moneda, o usa la seleccionada
    final code = currencyCode ?? currencyProvider.currency;
    final isUSD = code == 'USD';
    final formatter = NumberFormat.currency(
      locale: 'es',
      symbol: isUSD ? '\$' : code,
      decimalDigits: 2,
      customPattern: '#,##0.00',
    );
    return formatter.format(value.toDouble());
  }

  /// Formatea el valor recibido en formato compacto, solo visual, sin conversión.
  /// Asume que el valor ya está en la moneda correcta.
  static String formatCompact(BuildContext context, num value, {String? currencyCode}) {
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final code = currencyCode ?? currencyProvider.currency;
    final isUSD = code == 'USD';
    final compact = NumberFormat.compact(locale: 'en').format(value.toDouble());
    return isUSD ? '\$' + compact : compact;
  }
}
