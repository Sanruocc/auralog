import 'package:flutter/foundation.dart';

/// A simple logger utility for the application.
/// 
/// This class provides methods for logging messages at different levels.
/// In debug mode, it prints to the console, while in release mode it can be
/// configured to send logs to a service or simply suppress them.
class Logger {
  /// Log a debug message
  static void d(String tag, String message) {
    if (kDebugMode) {
      print('DEBUG [$tag]: $message');
    }
  }

  /// Log an info message
  static void i(String tag, String message) {
    if (kDebugMode) {
      print('INFO [$tag]: $message');
    }
  }

  /// Log a warning message
  static void w(String tag, String message) {
    if (kDebugMode) {
      print('WARNING [$tag]: $message');
    }
  }

  /// Log an error message
  static void e(String tag, String message) {
    if (kDebugMode) {
      print('ERROR [$tag]: $message');
    }
    // In a production app, you might want to send error logs to a service
    // even in release mode
  }
}
