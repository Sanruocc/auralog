// This file conditionally exports the correct database implementation
// based on the platform without causing compilation errors

// Use conditional exports to import the appropriate implementation
// dart.library.html is only available on web platforms
export 'database_connection_native.dart'
    if (dart.library.html) 'database_connection_web.dart';
