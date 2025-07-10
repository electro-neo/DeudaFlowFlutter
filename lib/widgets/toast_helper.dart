import 'package:flutter/material.dart';

class ToastHelper {
  static void showToast(BuildContext context, String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
