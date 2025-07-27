import 'package:flutter/material.dart';

class CurrencyProvider extends ChangeNotifier {
  String _currency = 'VES';
  // Map of currency code to rate (rate = how many units of that currency per 1 USD)
  Map<String, double> _exchangeRates = {};
  List<String> _availableCurrencies = ['USD', 'VES'];

  String get currency => _currency;
  Map<String, double> get exchangeRates => _exchangeRates;
  List<String> get availableCurrencies => _availableCurrencies;

  // For backward compatibility: VES rate
  double get rate => _exchangeRates['VES'] ?? 1.0;

  void setCurrency(String value) {
    _currency = value;
    notifyListeners();
  }

  void setExchangeRates(Map<String, double> rates) {
    _exchangeRates = Map<String, double>.from(rates);
    notifyListeners();
  }

  // Update available currencies from a list (e.g., from transactions)
  void setAvailableCurrencies(List<String> currencies) {
    // Siempre mantener USD como base
    final filtered = currencies
        .map((c) => c.toUpperCase())
        .where((c) => c != 'USD')
        .toSet()
        .toList();
    // Limitar a máximo 2 monedas adicionales
    if (filtered.length > 2) {
      filtered.removeRange(2, filtered.length);
    }
    _availableCurrencies = ['USD', ...filtered];
    notifyListeners();
  }

  // Set VES rate for legacy code
  void setRate(double value) {
    _exchangeRates['VES'] = value;
    notifyListeners();
  }

  // Set a single rate for a currency (solo para monedas distintas de USD)
  void setRateForCurrency(String currency, double rate) {
    final upper = currency.toUpperCase();
    // No permitir registrar tasa para USD
    if (upper == 'USD') return;
    // Solo permitir registrar tasa para monedas que estén en el listado permitido
    final allowed = [
      'VES',
      'COP',
      'EUR',
      'ARS',
      'BRL',
      'CLP',
      'MXN',
      'PEN',
      'UYU',
      'GBP',
      'CHF',
      'RUB',
      'TRY',
      'JPY',
      'CNY',
      'KRW',
      'INR',
      'SGD',
      'HKD',
      'CAD',
      'AUD',
      'NZD',
      'ZAR',
    ];
    if (!allowed.contains(upper)) return;

    // Limitar a solo 2 monedas adicionales a USD
    // Si la moneda ya tiene tasa, solo actualiza
    final nonUsdRates = _exchangeRates.keys.where((k) => k != 'USD').toList();
    if (!nonUsdRates.contains(upper) && nonUsdRates.length >= 2) {
      // No se puede registrar más de 2 monedas adicionales
      return;
    }
    _exchangeRates[upper] = rate;
    notifyListeners();
  }
}
