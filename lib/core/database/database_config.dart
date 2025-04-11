import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseConfig {
  // Define whether the app is being compiled for web or not
  // This will be used for conditional code compilation
  static const bool isWebPlatform = kIsWeb;

  // Database file name
  static const String databaseName = 'auralog_database.db';

  // Web database name
  static const String webDatabaseName = 'auralog_database';
}
