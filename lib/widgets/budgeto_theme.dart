import 'package:flutter/material.dart';
import 'budgeto_colors.dart';

class BudgetoTheme {
  static ThemeData light = ThemeData(
    fontFamily: 'Outfit',
    // Fondo principal del Scaffold (tema claro)
    scaffoldBackgroundColor: Colors.white,
    // ColorScheme principal (usa kGreenColor como color primario)
    colorScheme: const ColorScheme.light(
      primary: Color.fromARGB(255, 74, 1, 126),
    ), // kGreenColor: color principal/acento
    primaryColor: const Color.fromARGB(255, 65, 0, 150), // kGreenColor: color principal/acento
    cardColor: kCardColor, // kCardColor: fondo de tarjetas
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: kFontBlackC), // kFontBlackC: texto principal
      bodyMedium: TextStyle(color: kFontBlackC),
      bodySmall: TextStyle(color: kFontBlackC),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kGreenColor, // kGreenColor: fondo de AppBar
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hoverColor: kGreenColor, // kGreenColor: hover en campos
      focusColor:
          kTextFieldColor, // kTextFieldColor: fondo de TextField enfocado
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: kTextFieldBorderC,
        ), // kTextFieldBorderC: borde enfocado
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: kTextFieldBorderC,
        ), // kTextFieldBorderC: borde habilitado
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreenColor, // kGreenColor: fondo de botón
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        minimumSize: const Size(48, 48),
      ),
    ),
    cardTheme: CardThemeData(
      color: kCardColor, // kCardColor: fondo de tarjetas
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    ),
  );

  static ThemeData dark = ThemeData(
    fontFamily: 'Outfit',
    // Fondo principal del Scaffold (tema oscuro)
    scaffoldBackgroundColor:
        kDarkScaffoldC, // kDarkScaffoldC: fondo principal oscuro
    // ColorScheme principal (usa kDarkGreenColor como color primario)
    colorScheme: const ColorScheme.dark(
      primary: kDarkGreenColor,
    ), // kDarkGreenColor: color principal/acento oscuro
    primaryColor:
        kDarkGreenColor, // kDarkGreenColor: color principal/acento oscuro
    cardColor: kDarkCardC, // kDarkCardC: fondo de tarjetas oscuro
    appBarTheme: const AppBarTheme(
      backgroundColor:
          kDarkGreenColor, // kDarkGreenColor: fondo de AppBar oscuro
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hoverColor: kDarkGreenColor, // kDarkGreenColor: hover en campos
      focusColor:
          kDarkGreenColor, // kDarkGreenColor: fondo de TextField enfocado
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: kDarkGreenColor,
        ), // kDarkGreenColor: borde enfocado
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: kDarkGreenColor,
        ), // kDarkGreenColor: borde habilitado
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kDarkGreenColor, // kDarkGreenColor: fondo de botón
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        minimumSize: const Size(48, 48),
      ),
    ),
    cardTheme: CardThemeData(
      color: kDarkCardC, // kDarkCardC: fondo de tarjetas oscuro
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    ),
  );
}
