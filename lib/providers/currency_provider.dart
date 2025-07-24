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
    _availableCurrencies = currencies.toSet().toList();
    if (!_availableCurrencies.contains('USD')) {
      _availableCurrencies.insert(0, 'USD');
    }
    notifyListeners();
  }

  // Set VES rate for legacy code
  void setRate(double value) {
    _exchangeRates['VES'] = value;
    notifyListeners();
  }

  // Set a single rate for a currency
  void setRateForCurrency(String currency, double rate) {
    _exchangeRates[currency] = rate;
    notifyListeners();
  }
}
