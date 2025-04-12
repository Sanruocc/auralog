import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
import 'core/database/sqlite_helper.dart';

void main() async {
  // Catch any fatal errors during initialization
  try {
    WidgetsFlutterBinding.ensureInitialized();
    Logger.d('App', 'Application starting');

    // Request storage permissions on Android
    if (Platform.isAndroid) {
      try {
        Logger.d('App', 'Checking storage permissions');
        // Request storage permissions
        await _requestStoragePermissions();
      } catch (e) {
        Logger.e('App', 'Error checking/requesting permissions: $e');
        // Continue anyway, app might work with scoped storage
      }
    }

    // Load environment variables with error handling
    try {
      Logger.d('App', 'Loading environment variables');
      await dotenv.load(fileName: ".env");
      Logger.d('App', 'Environment variables loaded successfully');
    } catch (e, stackTrace) {
      Logger.e('App', 'Error loading .env file: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Continue with app initialization - the constants will use empty defaults
    }

    // Initialize Supabase with error handling
    try {
      Logger.d('App', 'Initializing Supabase connection');
      await Supabase.initialize(
        url: SupabaseConstants.url,
        anonKey: SupabaseConstants.anonKey,
      );
      Logger.d('App', 'Supabase initialized successfully');
    } catch (e, stackTrace) {
      Logger.e('App', 'Error initializing Supabase: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Add fallback or error handling here as needed
    }

    // Pre-initialize SQLite database to catch any issues early
    try {
      Logger.d('App', 'Pre-initializing SQLite database');
      final sqliteHelper = SQLiteHelper();
      // Check database integrity
      final isIntegrityOk = await sqliteHelper.checkDatabaseIntegrity();
      Logger.d('App', 'SQLite database integrity check: ${isIntegrityOk ? 'OK' : 'Failed'}');

      // If integrity check fails, try to recover
      if (!isIntegrityOk) {
        Logger.w('App', 'Attempting to recover database');
        await sqliteHelper.vacuumDatabase();
      }

      Logger.d('App', 'SQLite database pre-initialization successful');
    } catch (e) {
      Logger.e('App', 'SQLite database pre-initialization error: $e');
      // Continue anyway, the app will handle database errors
    }

    Logger.d('App', 'Starting application UI');
    runApp(
      const ProviderScope(
        child: AuraLogApp(),
      ),
    );
  } catch (e, stackTrace) {
    // Log any fatal errors during initialization
    debugPrint('FATAL ERROR: $e');
    debugPrintStack(stackTrace: stackTrace);

    // Still try to run the app with error handling
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Error initializing app: $e',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// Function to request storage permissions
Future<void> _requestStoragePermissions() async {
  if (Platform.isAndroid) {
    // For older Android versions, request storage permission
    if (await Permission.storage.status != PermissionStatus.granted) {
      await Permission.storage.request();
    }

    // For photos specifically (Android 13+)
    try {
      if (await Permission.photos.status != PermissionStatus.granted) {
        await Permission.photos.request();
      }
    } catch (e) {
      // Permission might not be available on this device/Android version
      Logger.w('Permissions', 'Photos permission not available: $e');
    }

    // For external storage (dangerous permission, might be rejected)
    try {
      if (await Permission.manageExternalStorage.status !=
          PermissionStatus.granted) {
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      // Permission might not be available on this device/Android version
      Logger.w('Permissions',
          'Manage external storage permission not available: $e');
    }
  }
}

class AuraLogApp extends ConsumerWidget {
  const AuraLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AuraLog',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
