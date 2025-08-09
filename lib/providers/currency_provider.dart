import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/supabase_service.dart';

class CurrencyProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final _settingsBox = Hive.box('user_settings');
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  static const List<String> allowedCurrencies = [
    'USD', 'VES', 'COP', 'EUR', 'BRL', 'ARS', 'CLP', 'MXN', 'PEN', 'BOB',
    'PYG', 'UYU', 'CRC', 'DOP', 'GTQ', 'HNL', 'NIO', 'PAB', 'BZD', 'JMD',
    'TTD', 'HTG', 'XCD', 'CAD', 'GBP', 'CHF', 'JPY', 'CNY', 'KRW', 'INR',
    'RUB', 'TRY', 'ZAR', 'AUD', 'NZD', 'SGD', 'HKD', 'SEK', 'NOK', 'DKK',
    'PLN', 'CZK', 'HUF', 'RON', 'BGN', 'HRK', 'IDR', 'MYR', 'THB', 'VND',
    'EGP', 'SAR', 'AED', 'ILS', 'TWD', 'PHP', 'MAD', 'KZT', 'UAH', 'GHS',
    'NGN', 'PKR', 'BDT', 'LKR', 'MMK', 'KHR', 'LAK', 'MNT', 'MOP', 'BAM',
    'MKD', 'RSD', 'ISK', 'GEL', 'AZN', 'QAR', 'KWD', 'OMR', 'BHD', 'JOD',
    'LBP', 'SYP', 'IQD', 'AFN', 'IRR', 'YER', 'SDG', 'DZD', 'TND', 'LYD',
    'MRU', 'SOS', 'TZS', 'KES', 'UGX', 'RWF', 'BIF', 'MWK', 'ZMW', 'MZN',
    'SZL', 'LSL', 'NAD', 'BWP', 'ZWL', 'SCR', 'MUR', 'KMF', 'DJF', 'ETB',
    'ERN', 'SLL', 'GMD', 'GNF', 'CVE', 'XOF', 'XAF', 'XPF', 'WST', 'TOP',
    'FJD', 'PGK', 'SBD', 'VUV', 'KID', 'TVD', 'BSD', 'BBD', 'KYD', 'BMD',
    'ANG', 'AWG', 'SRD', 'GYD', 'BND', 'NPR', 'BTN', 'MVR', 'AMD', 'KGS',
    'UZS', 'TJS', 'TMT', 'BYN', 'MDL',
  ];
  String _currency = 'USD';
  Map<String, double> _exchangeRates = {};
  List<String> _availableCurrencies = ['USD'];

  String get currency => _currency;
  Map<String, double> get exchangeRates => _exchangeRates;
  List<String> get availableCurrencies => _availableCurrencies;

  double get rate => _exchangeRates['VES'] ?? 1.0;

  CurrencyProvider() {
    _connectivitySubscription = 
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    final isOnline = !result.contains(ConnectivityResult.none);
    if (isOnline) {
      debugPrint('[SYNC][RATES] Conexión detectada. Iniciando sincronización...');
      syncWithSupabase();
    }
  }

  Future<void> loadInitialData() async {
    final cachedRates = _settingsBox.get('exchange_rates');
    if (cachedRates != null && cachedRates is Map) {
      _updateStateFromRates(cachedRates.cast<String, double>(), notify: false);
    }
    await syncWithSupabase(fetchOnNoSync: true);
    notifyListeners();
  }

  Future<void> syncWithSupabase({bool fetchOnNoSync = false}) async {
    final isOnline = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
    if (!isOnline) {
      debugPrint('[SYNC][RATES] No hay conexión. Sincronización omitida.');
      return;
    }

    // 1. Sincronizar eliminaciones pendientes
    final pendingDeletions = _settingsBox.get('rates_to_delete', defaultValue: <String>[])!.cast<String>();
    if (pendingDeletions.isNotEmpty) {
      debugPrint('[SYNC][RATES] Conectado. Eliminando tasas pendientes: $pendingDeletions');
      final success = await _supabaseService.deleteExchangeRates(pendingDeletions);
      if (success) {
        await _settingsBox.put('rates_to_delete', <String>[]);
      }
    }

    // 2. Sincronizar actualizaciones/adiciones pendientes
    final needsSync = _settingsBox.get('rates_need_sync') ?? false;
    if (needsSync) {
      debugPrint('[SYNC][RATES] Conectado. Enviando tasas pendientes...');
      final success = await _supabaseService.saveExchangeRates(_exchangeRates);
      if (success) {
        await _settingsBox.put('rates_need_sync', false);
      }
    } else if (fetchOnNoSync) {
      // 3. Si no hay nada que enviar, buscar actualizaciones desde Supabase
      debugPrint('[SYNC][RATES] Conectado. Buscando actualizaciones de tasas...');
      final supabaseRates = await _supabaseService.getExchangeRates();
      if (supabaseRates.isNotEmpty && !const MapEquality().equals(supabaseRates, _exchangeRates)) {
        _updateStateFromRates(supabaseRates);
        await _settingsBox.put('exchange_rates', supabaseRates);
      }
    }
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
    await _settingsBox.put('exchange_rates', _exchangeRates);
    final isOnline = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);

    if (isOnline) {
      debugPrint('[SYNC][RATES] Conectado. Guardando tasas en Supabase...');
      final success = await _supabaseService.saveExchangeRates(_exchangeRates);
      await _settingsBox.put('rates_need_sync', !success);
    } else {
      debugPrint('[SYNC][RATES] Offline. Marcando tasas como pendientes de sincronización.');
      await _settingsBox.put('rates_need_sync', true);
    }
  }

  void setCurrency(String value) {
    _currency = value;
    notifyListeners();
  }

  void addManualCurrency(String currency) {
    final upper = currency.toUpperCase();
    if (upper == 'USD' || _exchangeRates.containsKey(upper)) return;

    _exchangeRates[upper] = 0.0;
    _updateStateFromRates(_exchangeRates);
    _persistRates();
  }

  Future<void> removeManualCurrency(String currency) async {
    final upper = currency.toUpperCase();
    if (upper == 'USD') return;

    if (_exchangeRates.containsKey(upper)) {
      _exchangeRates.remove(upper);
      _updateStateFromRates(_exchangeRates);

      final List<String> pendingDeletions = 
          _settingsBox.get('rates_to_delete', defaultValue: <String>[])!.cast<String>();
      if (!pendingDeletions.contains(upper)) {
        pendingDeletions.add(upper);
        await _settingsBox.put('rates_to_delete', pendingDeletions);
      }

      await _persistRates();
    }
  }

  void setRate(double value) {
    setRateForCurrency('VES', value);
  }

  void setRateForCurrency(String currency, double rate) {
    final upper = currency.toUpperCase();
    if (upper == 'USD' || !allowedCurrencies.contains(upper)) return;

    _exchangeRates[upper] = rate;
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