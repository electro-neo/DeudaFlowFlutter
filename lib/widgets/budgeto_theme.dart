import 'package:flutter/material.dart';
import 'budgeto_colors.dart';

class BudgetoTheme {
  static ThemeData light = ThemeData(
    fontFamily: 'Outfit',
    // Fondo principal del Scaffold (tema claro)
    scaffoldBackgroundColor: Colors.white,
    // Transiciones de navegación suaves y consistentes en todas las plataformas
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    // ColorScheme principal (usa kGreenColor como color primario)
    colorScheme: const ColorScheme.light(
      primary: Color.fromARGB(
        255,
        84,
        10,
        136,
      ), // kGreenColor: color principal/acento
      secondary: Color.fromARGB(
        255,
        79,
        155,
        247,
      ), // Color secundario para acentos y bordes enfocados
      onSecondary:
          Colors.white, // <--- Aquí defines el color del texto sobre secondary
    ), // kGreenColor: color principal/acento
    primaryColor: const Color.fromARGB(
      255,
      66,
      6,
      144,
    ), // kGreenColor: color principal/acento
    cardColor: kCardColor, // kCardColor: fondo de tarjetas
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: kFontBlackC), // kFontBlackC: texto principal
      bodyMedium: TextStyle(
        color: kFontBlackC,
      ), // kFontBlackC: texto secundario
      bodySmall: TextStyle(color: kFontBlackC), // kFontBlackC: texto pequeño
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
      focusColor: const Color.fromARGB(
        255,
        133,
        189,
        246,
      ), // kTextFieldColor: fondo de TextField enfocado
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color.fromARGB(255, 26, 98, 243),
        ), // kTextFieldBorderC: borde enfocado
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color.fromARGB(255, 1, 84, 248),
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
    // Transiciones de navegación suaves y consistentes en todas las plataformas
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    // ColorScheme principal (usa kDarkGreenColor como color primario)
    colorScheme: const ColorScheme.dark(
      primary: kDarkGreenColor,
      secondary:
          kDarkGreenColor, // Color secundario para acentos y bordes enfocados en oscuro
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
