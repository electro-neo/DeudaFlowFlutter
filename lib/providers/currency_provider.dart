import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';
import '../services/supabase_service.dart';

class CurrencyProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final _settingsBox = Hive.box('user_settings');

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
  String _currency = 'USD';
  Map<String, double> _exchangeRates = {};
  List<String> _availableCurrencies = ['USD'];

  String get currency => _currency;
  Map<String, double> get exchangeRates => _exchangeRates;
  List<String> get availableCurrencies => _availableCurrencies;

  double get rate => _exchangeRates['VES'] ?? 1.0;

  Future<void> loadInitialRates() async {
    // 1. Cargar desde Hive para un inicio rápido
    final cachedRates = _settingsBox.get('exchange_rates');
    if (cachedRates != null && cachedRates is Map) {
      _updateStateFromRates(
        cachedRates.cast<String, double>(),
        notify: false, // No notificar hasta tener datos de Supabase
      );
    }

    // 2. Cargar desde Supabase
    final supabaseRates = await _supabaseService.getExchangeRates();
    if (supabaseRates.isNotEmpty) {
      // Comprobar si los datos de Supabase son diferentes a los actuales
      if (!const MapEquality().equals(supabaseRates, _exchangeRates)) {
        _updateStateFromRates(supabaseRates);
        await _settingsBox.put('exchange_rates', supabaseRates);
      }
    }
    notifyListeners(); // Notificar a los listeners al final
  }

  void _updateStateFromRates(Map<String, double> rates, {bool notify = true}) {
    _exchangeRates = Map<String, double>.from(rates);
    final currencyKeys = rates.keys.toList();
    currencyKeys.remove('USD');
    currencyKeys.sort();
    _availableCurrencies = ['USD', ...currencyKeys];
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _persistRates() async {
    await _supabaseService.saveExchangeRates(_exchangeRates);
    await _settingsBox.put('exchange_rates', _exchangeRates);
  }

  void setCurrency(String value) {
    _currency = value;
    notifyListeners();
  }

  void addManualCurrency(String currency) {
    final upper = currency.toUpperCase();
    if (upper == 'USD' || _exchangeRates.containsKey(upper)) return;

    // Se añade con una tasa de 0.0, el usuario debe establecerla
    _exchangeRates[upper] = 0.0;
    _updateStateFromRates(_exchangeRates);
    _persistRates();
  }

  void removeManualCurrency(String currency) {
    final upper = currency.toUpperCase();
    if (upper == 'USD') return;

    if (_exchangeRates.containsKey(upper)) {
      _exchangeRates.remove(upper);
      _updateStateFromRates(_exchangeRates);
      _persistRates();
    }
  }

  void setRate(double value) {
    setRateForCurrency('VES', value);
  }

  void setRateForCurrency(String currency, double rate) {
    final upper = currency.toUpperCase();
    if (upper == 'USD' || !allowedCurrencies.contains(upper)) return;

    _exchangeRates[upper] = rate;
    // No es necesario llamar a _updateStateFromRates aquí si solo cambia un valor
    notifyListeners();
    _persistRates();
  }

  double? getRateFor(String currencyCode) {
    if (currencyCode == 'USD') {
      return 1.0;
    }
    return _exchangeRates[currencyCode];
  }
}
