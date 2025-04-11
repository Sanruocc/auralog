// This file is only used when running on web platforms
import 'package:drift/drift.dart';
import 'package:drift/web.dart';

// Web platform implementation of database connection
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    // Use IndexedDb for web storage
    return WebDatabase('auralog_database');
  });
}
