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

  // Set a single rate for a currency
  void setRateForCurrency(String currency, double rate) {
    // Solo permitir registrar tasa para USD o las 2 monedas adicionales
    final allowed = _availableCurrencies.take(3).toList();
    if (allowed.contains(currency.toUpperCase())) {
      _exchangeRates[currency.toUpperCase()] = rate;
      notifyListeners();
    }
  }
}
