import 'package:flutter/material.dart';
import '../widgets/budgeto_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = BudgetoTheme.light;

  ThemeData get themeData => _themeData;

  void setTheme(ThemeData theme) {
    _themeData = theme;
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeData.brightness == Brightness.dark) {
      setTheme(BudgetoTheme.light);
    } else {
      setTheme(BudgetoTheme.dark);
    }
  }
}
