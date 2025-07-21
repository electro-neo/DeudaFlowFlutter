import 'package:flutter/material.dart';

// =================== PALETA DE COLORES GLOBAL BUDGETO ===================

/// Color principal de la app (botones, appbar, acentos principales en tema claro)
/// Usado en: budgeto_theme.dart (colorScheme, primaryColor, AppBar, botones, etc)
const kGreenColor = Color.fromARGB(255, 0, 90, 150);

/// Color de fondo de los TextField en tema claro
/// Usado en: budgeto_theme.dart (inputDecorationTheme.focusColor)
const kTextFieldColor = Color(0xffF7F8F9);

/// Color del borde de los TextField en tema claro
/// Usado en: budgeto_theme.dart (inputDecorationTheme.focusedBorder, enabledBorder)
const kTextFieldBorderC = Color(0xffECEFF5);

/// Color principal para textos en tema claro
/// Usado en: budgeto_theme.dart (textTheme.bodyLarge/bodyMedium/bodySmall)
const kFontBlackC = Color(0xff353535);

/// Gris para íconos, bordes secundarios o deshabilitados
/// Usado en: (definido, pero no se detectaron usos directos)
const kGrayC = Color(0xffADB6C1);

/// Gris para textos secundarios
/// Usado en: (definido, pero no se detectaron usos directos)
const kGrayTextC = Color(0xff9FA6B6);

/// Gris para fondo de TextField (alias de kTextFieldColor)
/// Usado en: (definido, pero no se detectaron usos directos)
const kGrayTextfieldC = Color(0xffF7F8F9);

/// Verde oscuro para acentos secundarios
/// Usado en: (definido, pero no se detectaron usos directos)
const kGreenDarkC = Color(0xff137E75);

/// Color de fondo de tarjetas (Card) en tema claro
/// Usado en: budgeto_theme.dart (cardColor, CardTheme)
const kCardColor = Color(0xffEDF1F0);

/// Verde oscuro para fondo de barra de navegación inferior
/// Usado en: (definido, pero no se detectaron usos directos)
const kGreenNavC = Color.fromARGB(255, 94, 9, 8);

/// Color de fondo del Scaffold en tema oscuro
/// Usado en: budgeto_theme.dart (scaffoldBackgroundColor, dark theme)
const kDarkScaffoldC = Color(0xff121418);

/// Color de fondo de tarjetas (Card) en tema oscuro
/// Usado en: budgeto_theme.dart (cardColor, CardTheme, dark theme)
const kDarkCardC = Color(0xff1B1F24);

/// Color principal/acento en tema oscuro (botones, appbar, etc)
/// Usado en: budgeto_theme.dart (colorScheme, primaryColor, AppBar, botones, etc, dark theme)
const kDarkGreenColor = Color.fromARGB(255, 43, 11, 111);

/// Verde oscuro para fondos secundarios en tema oscuro
/// Usado en: (definido, pero no se detectaron usos directos)
const kDarkGreenBackC = Color(0xff027273);

/// Color de íconos activos en barra de navegación inferior (oscuro)
/// Usado en: (definido, pero no se detectaron usos directos)
const kDarkGreenNavIconC = Color.fromARGB(255, 25, 0, 93);

/// Fondo translúcido para el contenedor deslizable de tipo de transacción
/// Usado en: add_global_transaction_modal.dart, client_form.dart, transaction_form.dart
/// Propósito: fondo visual para selector de tipo de transacción (deuda/pago)
const kSliderContainerBg = Color.fromARGB(33, 33, 150, 243);
