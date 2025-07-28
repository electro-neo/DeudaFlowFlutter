import 'package:flutter/material.dart';

class CurrencyProvider extends ChangeNotifier {
  // Listado global de monedas permitidas para toda la app
  static const List<String> allowedCurrencies = [
    'USD',
    'VES',
    'COP',
    'EUR',
    'BRL',
    'ARS',
    'CLP',
    'MXN',
    'PEN',
    'BOB',
    'PYG',
    'UYU',
    'CRC',
    'DOP',
    'GTQ',
    'HNL',
    'NIO',
    'PAB',
    'BZD',
    'JMD',
    'TTD',
    'HTG',
    'XCD',
    'CAD',
    'GBP',
    'CHF',
    'JPY',
    'CNY',
    'KRW',
    'INR',
    'RUB',
    'TRY',
    'ZAR',
    'AUD',
    'NZD',
    'SGD',
    'HKD',
    'SEK',
    'NOK',
    'DKK',
    'PLN',
    'CZK',
    'HUF',
    'RON',
    'BGN',
    'HRK',
    'IDR',
    'MYR',
    'THB',
    'VND',
    'EGP',
    'SAR',
    'AED',
    'ILS',
    'TWD',
    'PHP',
    'MAD',
    'KZT',
    'UAH',
    'GHS',
    'NGN',
    'PKR',
    'BDT',
    'LKR',
    'MMK',
    'KHR',
    'LAK',
    'MNT',
    'MOP',
    'BAM',
    'MKD',
    'RSD',
    'ISK',
    'GEL',
    'AZN',
    'QAR',
    'KWD',
    'OMR',
    'BHD',
    'JOD',
    'LBP',
    'SYP',
    'IQD',
    'AFN',
    'IRR',
    'YER',
    'SDG',
    'DZD',
    'TND',
    'LYD',
    'MRU',
    'SOS',
    'TZS',
    'KES',
    'UGX',
    'RWF',
    'BIF',
    'MWK',
    'ZMW',
    'MZN',
    'SZL',
    'LSL',
    'NAD',
    'BWP',
    'ZWL',
    'SCR',
    'MUR',
    'KMF',
    'DJF',
    'ETB',
    'ERN',
    'SLL',
    'GMD',
    'GNF',
    'CVE',
    'XOF',
    'XAF',
    'XPF',
    'WST',
    'TOP',
    'FJD',
    'PGK',
    'SBD',
    'VUV',
    'KID',
    'TVD',
    'BSD',
    'BBD',
    'KYD',
    'BMD',
    'ANG',
    'AWG',
    'SRD',
    'GYD',
    'BND',
    'NPR',
    'BTN',
    'MVR',
    'AMD',
    'KGS',
    'UZS',
    'TJS',
    'TMT',
    'BYN',
    'MDL',
  ];
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
  // Solo debe usarse para actualizar monedas detectadas automáticamente,
  // nunca eliminar monedas agregadas manualmente salvo que el usuario lo indique.
  void setAvailableCurrencies(
    List<String> currencies, {
    List<String>? manualCurrencies,
  }) {
    // Siempre mantener USD como base
    final filtered = currencies
        .map((c) => c.toUpperCase())
        .where((c) => c != 'USD')
        .toSet();

    // Si hay monedas agregadas manualmente, asegurarlas en la lista
    final manual =
        manualCurrencies
            ?.map((c) => c.toUpperCase())
            .where((c) => c != 'USD')
            .toSet() ??
        {};
    final allCurrencies = {'USD', ...filtered, ...manual};

    // Solo eliminar tasas de monedas que no estén en la lista final
    _exchangeRates.removeWhere((key, value) => !allCurrencies.contains(key));
    _availableCurrencies = allCurrencies.toList();
    notifyListeners();
  }

  // Agrega una moneda manualmente y la mantiene en la lista hasta que el usuario la quite explícitamente
  void addManualCurrency(String currency) {
    final upper = currency.toUpperCase();
    if (upper == 'USD') return;
    if (!_availableCurrencies.contains(upper)) {
      _availableCurrencies.add(upper);
      notifyListeners();
    }
  }

  // Elimina una moneda manualmente agregada (y su tasa)
  void removeManualCurrency(String currency) {
    final upper = currency.toUpperCase();
    if (upper == 'USD') return;
    if (_availableCurrencies.contains(upper)) {
      _availableCurrencies.remove(upper);
      _exchangeRates.remove(upper);
      notifyListeners();
    }
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
      'BRL',
      'ARS',
      'CLP',
      'MXN',
      'PEN',
      'BOB',
      'PYG',
      'UYU',
      'CRC',
      'DOP',
      'GTQ',
      'HNL',
      'NIO',
      'PAB',
      'BZD',
      'JMD',
      'TTD',
      'HTG',
      'XCD',
      'CAD',
      'GBP',
      'CHF',
      'JPY',
      'CNY',
      'KRW',
      'INR',
      'RUB',
      'TRY',
      'ZAR',
      'AUD',
      'NZD',
      'SGD',
      'HKD',
      'SEK',
      'NOK',
      'DKK',
      'PLN',
      'CZK',
      'HUF',
      'RON',
      'BGN',
      'HRK',
      'IDR',
      'MYR',
      'THB',
      'VND',
      'EGP',
      'SAR',
      'AED',
      'ILS',
      'TWD',
      'PHP',
      'MAD',
      'KZT',
      'UAH',
      'GHS',
      'NGN',
      'PKR',
      'BDT',
      'LKR',
      'MMK',
      'KHR',
      'LAK',
      'MNT',
      'MOP',
      'BAM',
      'MKD',
      'RSD',
      'ISK',
      'GEL',
      'AZN',
      'QAR',
      'KWD',
      'OMR',
      'BHD',
      'JOD',
      'LBP',
      'SYP',
      'IQD',
      'AFN',
      'IRR',
      'YER',
      'SDG',
      'DZD',
      'TND',
      'LYD',
      'MRU',
      'SOS',
      'TZS',
      'KES',
      'UGX',
      'RWF',
      'BIF',
      'MWK',
      'ZMW',
      'MZN',
      'SZL',
      'LSL',
      'NAD',
      'BWP',
      'ZWL',
      'SCR',
      'MUR',
      'KMF',
      'DJF',
      'ETB',
      'ERN',
      'SLL',
      'GMD',
      'GNF',
      'CVE',
      'XOF',
      'XAF',
      'XPF',
      'WST',
      'TOP',
      'FJD',
      'PGK',
      'SBD',
      'VUV',
      'KID',
      'TVD',
      'BSD',
      'BBD',
      'KYD',
      'BMD',
      'ANG',
      'AWG',
      'SRD',
      'GYD',
      'BND',
      'NPR',
      'BTN',
      'MVR',
      'AMD',
      'KGS',
      'UZS',
      'TJS',
      'TMT',
      'BYN',
      'MDL',
      'USD',
      'MXN',
    ];
    if (!allowed.contains(upper)) return;
    // Eliminar el límite de solo 2 monedas adicionales a USD
    _exchangeRates[upper] = rate;
    notifyListeners();
  }
}
