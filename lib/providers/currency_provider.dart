import 'package:flutter/material.dart';

class CurrencyProvider extends ChangeNotifier {
  String _currency = 'VES';
  double _rate = 1.0;

  String get currency => _currency;
  double get rate => _rate;

  void setCurrency(String value) {
    _currency = value;
    notifyListeners();
  }

  void setRate(double value) {
    _rate = value;
    notifyListeners();
  }
}
