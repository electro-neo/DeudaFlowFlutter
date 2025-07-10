import 'package:flutter/material.dart';

class TransactionFilterProvider extends ChangeNotifier {
  String? _type;
  String? get type => _type;

  String? _clientId;
  String? get clientId => _clientId;

  void setType(String? type) {
    _type = type;
    notifyListeners();
  }

  void setClientId(String? clientId) {
    _clientId = clientId;
    notifyListeners();
  }

  void clear() {
    _type = null;
    _clientId = null;
    notifyListeners();
  }
}
