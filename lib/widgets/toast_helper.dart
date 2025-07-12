import 'package:flutter/material.dart';

class ToastHelper {
  static void showToast(BuildContext context, String message, {Color? color}) {
    // Solo muestra el SnackBar si el contexto sigue montado
    if (context is Element && !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
