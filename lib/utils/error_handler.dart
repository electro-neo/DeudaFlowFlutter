import 'package:flutter/material.dart';
import '../widgets/toast_helper.dart';

class ErrorHandler {
  static void handleError(BuildContext context, dynamic error, {String? fallback}) {
    String message = fallback ?? 'Ocurrió un error inesperado';
    if (error is Exception) {
      message = error.toString();
    } else if (error is String) {
      message = error;
    }
    ToastHelper.showToast(context, message, color: Colors.red);
  }
}
