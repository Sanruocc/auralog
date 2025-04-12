import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/journal/models/journal_entry.dart';
import '../utils/logger.dart';

class SQLiteHelper {
  static final SQLiteHelper _instance = SQLiteHelper._internal();
  static Database? _database;

  // Database name and version
  static const String _databaseName = 'auralog.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableJournalEntries = 'journal_entries';
  static const String tableAttachments = 'attachments';
  static const String tableHabitItems = 'habit_items';

  // Factory constructor
  factory SQLiteHelper() {
    return _instance;
  }

  // Internal constructor
  SQLiteHelper._internal();

  // Get database instance
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    try {
      Logger.d('SQLiteHelper', 'Initializing database');
      
      // Get the application documents directory
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      Logger.d('SQLiteHelper', 'Database path: $path');

      // Make sure the directory exists
      if (!await Directory(dirname(path)).exists()) {
        await Directory(dirname(path)).create(recursive: true);
        Logger.d('SQLiteHelper', 'Created database directory');
      }

      // Open the database
      Database db = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) {
          Logger.d('SQLiteHelper', 'Database opened successfully');
        },
      );

      return db;
    } catch (e, stackTrace) {
      Logger.e('SQLiteHelper', 'Error initializing database: $e');
      debugPrintStack(stackTrace: stackTrace);
      
      // Try to use a different location as fallback
      try {
        Logger.w('SQLiteHelper', 'Trying fallback database location');
        Directory tempDir = await getTemporaryDirectory();
        String fallbackPath = join(tempDir.path, _databaseName);
        
        Database db = await openDatabase(
          fallbackPath,
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
        
        Logger.d('SQLiteHelper', 'Fallback database created successfully');
        return db;
      } catch (fallbackError) {
        Logger.e('SQLiteHelper', 'Fallback database creation failed: $fallbackError');
        rethrow;
      }
    }
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    Logger.d('SQLiteHelper', 'Creating database tables');
    
    try {
      // Create journal_entries table
      await db.execute('''
        CREATE TABLE $tableJournalEntries (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          mood TEXT NOT NULL,
          sentiment TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          summary TEXT
        )
      ''');
      Logger.d('SQLiteHelper', 'Created journal_entries table');
      
      // Create attachments table
      await db.execute('''
        CREATE TABLE $tableAttachments (
          id TEXT PRIMARY KEY,
          entry_id TEXT NOT NULL,
          type TEXT NOT NULL,
          url TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (entry_id) REFERENCES $tableJournalEntries (id) ON DELETE CASCADE
        )
      ''');
      Logger.d('SQLiteHelper', 'Created attachments table');
      
      // Create habit_items table
      await db.execute('''
        CREATE TABLE $tableHabitItems (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          is_completed INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          target_date TEXT,
          frequency INTEGER NOT NULL DEFAULT 1,
          is_synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
      Logger.d('SQLiteHelper', 'Created habit_items table');
      
      // Enable foreign keys
      await db.execute('PRAGMA foreign_keys = ON');
      
    } catch (e, stackTrace) {
      Logger.e('SQLiteHelper', 'Error creating database tables: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // Upgrade database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.d('SQLiteHelper', 'Upgrading database from $oldVersion to $newVersion');
    
    // No upgrades needed yet since this is the first version
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      Logger.d('SQLiteHelper', 'Database closed');
    }
  }

  // Journal Entry Methods
  
  // Insert a journal entry
  Future<void> insertJournalEntry(JournalEntry entry) async {
    try {
      final db = await database;
      
      // Convert entry to map
      final Map<String, dynamic> entryMap = {
        'id': entry.id,
        'user_id': entry.userId,
        'content': entry.content,
        'created_at': entry.createdAt.toIso8601String(),
        'mood': entry.mood.name,
        'sentiment': entry.sentiment?.name,
        'is_synced': entry.isSynced ? 1 : 0,
        'summary': entry.summary,
      };
      
      // Insert entry
      await db.insert(
        tableJournalEntries,
        entryMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Insert attachments
      for (final attachment in entry.attachments) {
        await insertAttachment(attachment);
      }
      
      Logger.d('SQLiteHelper', 'Inserted journal entry: ${entry.id}');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error inserting journal entry: $e');
      rethrow;
    }
  }
  
  // Update a journal entry
  Future<void> updateJournalEntry(JournalEntry entry) async {
    try {
      final db = await database;
      
      // Convert entry to map
      final Map<String, dynamic> entryMap = {
        'id': entry.id,
        'user_id': entry.userId,
        'content': entry.content,
        'created_at': entry.createdAt.toIso8601String(),
        'mood': entry.mood.name,
        'sentiment': entry.sentiment?.name,
        'is_synced': entry.isSynced ? 1 : 0,
        'summary': entry.summary,
      };
      
      // Update entry
      await db.update(
        tableJournalEntries,
        entryMap,
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      
      // Delete existing attachments
      await db.delete(
        tableAttachments,
        where: 'entry_id = ?',
        whereArgs: [entry.id],
      );
      
      // Insert new attachments
      for (final attachment in entry.attachments) {
        await insertAttachment(attachment);
      }
      
      Logger.d('SQLiteHelper', 'Updated journal entry: ${entry.id}');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error updating journal entry: $e');
      rethrow;
    }
  }
  
  // Delete a journal entry
  Future<void> deleteJournalEntry(String id) async {
    try {
      final db = await database;
      
      // Delete attachments first (if foreign keys are not enabled)
      await db.delete(
        tableAttachments,
        where: 'entry_id = ?',
        whereArgs: [id],
      );
      
      // Delete entry
      await db.delete(
        tableJournalEntries,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      Logger.d('SQLiteHelper', 'Deleted journal entry: $id');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error deleting journal entry: $e');
      rethrow;
    }
  }
  
  // Get all journal entries
  Future<List<JournalEntry>> getAllJournalEntries() async {
    try {
      final db = await database;
      
      // Query entries
      final List<Map<String, dynamic>> entryMaps = await db.query(tableJournalEntries);
      
      // Convert to JournalEntry objects
      final List<JournalEntry> entries = [];
      
      for (final entryMap in entryMaps) {
        // Get attachments for this entry
        final List<Map<String, dynamic>> attachmentMaps = await db.query(
          tableAttachments,
          where: 'entry_id = ?',
          whereArgs: [entryMap['id']],
        );
        
        // Convert attachment maps to Attachment objects
        final List<Attachment> attachments = attachmentMaps.map((attachmentMap) {
          return Attachment(
            id: attachmentMap['id'] as String,
            entryId: attachmentMap['entry_id'] as String,
            type: AttachmentType.values.firstWhere(
              (type) => type.name == attachmentMap['type'],
              orElse: () => AttachmentType.photo,
            ),
            url: attachmentMap['url'] as String,
            createdAt: DateTime.parse(attachmentMap['created_at'] as String),
            isSynced: attachmentMap['is_synced'] == 1,
          );
        }).toList();
        
        // Create JournalEntry with attachments
        entries.add(JournalEntry(
          id: entryMap['id'] as String,
          userId: entryMap['user_id'] as String,
          content: entryMap['content'] as String,
          createdAt: DateTime.parse(entryMap['created_at'] as String),
          mood: Mood.values.firstWhere(
            (mood) => mood.name == entryMap['mood'],
            orElse: () => Mood.okay,
          ),
          sentiment: entryMap['sentiment'] != null
              ? Sentiment.values.firstWhere(
                  (sentiment) => sentiment.name == entryMap['sentiment'],
                  orElse: () => Sentiment.neutral,
                )
              : null,
          isSynced: entryMap['is_synced'] == 1,
          summary: entryMap['summary'] as String?,
          attachments: attachments,
        ));
      }
      
      Logger.d('SQLiteHelper', 'Retrieved ${entries.length} journal entries');
      return entries;
    } catch (e, stackTrace) {
      Logger.e('SQLiteHelper', 'Error getting journal entries: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Return empty list as fallback
      return [];
    }
  }
  
  // Get unsynced journal entries
  Future<List<JournalEntry>> getUnsyncedJournalEntries() async {
    try {
      final db = await database;
      
      // Query unsynced entries
      final List<Map<String, dynamic>> entryMaps = await db.query(
        tableJournalEntries,
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      
      // Convert to JournalEntry objects (same as getAllJournalEntries)
      final List<JournalEntry> entries = [];
      
      for (final entryMap in entryMaps) {
        // Get attachments for this entry
        final List<Map<String, dynamic>> attachmentMaps = await db.query(
          tableAttachments,
          where: 'entry_id = ?',
          whereArgs: [entryMap['id']],
        );
        
        // Convert attachment maps to Attachment objects
        final List<Attachment> attachments = attachmentMaps.map((attachmentMap) {
          return Attachment(
            id: attachmentMap['id'] as String,
            entryId: attachmentMap['entry_id'] as String,
            type: AttachmentType.values.firstWhere(
              (type) => type.name == attachmentMap['type'],
              orElse: () => AttachmentType.photo,
            ),
            url: attachmentMap['url'] as String,
            createdAt: DateTime.parse(attachmentMap['created_at'] as String),
            isSynced: attachmentMap['is_synced'] == 1,
          );
        }).toList();
        
        // Create JournalEntry with attachments
        entries.add(JournalEntry(
          id: entryMap['id'] as String,
          userId: entryMap['user_id'] as String,
          content: entryMap['content'] as String,
          createdAt: DateTime.parse(entryMap['created_at'] as String),
          mood: Mood.values.firstWhere(
            (mood) => mood.name == entryMap['mood'],
            orElse: () => Mood.okay,
          ),
          sentiment: entryMap['sentiment'] != null
              ? Sentiment.values.firstWhere(
                  (sentiment) => sentiment.name == entryMap['sentiment'],
                  orElse: () => Sentiment.neutral,
                )
              : null,
          isSynced: entryMap['is_synced'] == 1,
          summary: entryMap['summary'] as String?,
          attachments: attachments,
        ));
      }
      
      Logger.d('SQLiteHelper', 'Retrieved ${entries.length} unsynced journal entries');
      return entries;
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error getting unsynced journal entries: $e');
      // Return empty list as fallback
      return [];
    }
  }
  
  // Attachment Methods
  
  // Insert an attachment
  Future<void> insertAttachment(Attachment attachment) async {
    try {
      final db = await database;
      
      // Convert attachment to map
      final Map<String, dynamic> attachmentMap = {
        'id': attachment.id,
        'entry_id': attachment.entryId,
        'type': attachment.type.name,
        'url': attachment.url,
        'created_at': attachment.createdAt.toIso8601String(),
        'is_synced': attachment.isSynced ? 1 : 0,
      };
      
      // Insert attachment
      await db.insert(
        tableAttachments,
        attachmentMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      Logger.d('SQLiteHelper', 'Inserted attachment: ${attachment.id}');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error inserting attachment: $e');
      rethrow;
    }
  }
  
  // Get attachments for a journal entry
  Future<List<Attachment>> getAttachmentsForEntry(String entryId) async {
    try {
      final db = await database;
      
      // Query attachments
      final List<Map<String, dynamic>> attachmentMaps = await db.query(
        tableAttachments,
        where: 'entry_id = ?',
        whereArgs: [entryId],
      );
      
      // Convert to Attachment objects
      final List<Attachment> attachments = attachmentMaps.map((attachmentMap) {
        return Attachment(
          id: attachmentMap['id'] as String,
          entryId: attachmentMap['entry_id'] as String,
          type: AttachmentType.values.firstWhere(
            (type) => type.name == attachmentMap['type'],
            orElse: () => AttachmentType.photo,
          ),
          url: attachmentMap['url'] as String,
          createdAt: DateTime.parse(attachmentMap['created_at'] as String),
          isSynced: attachmentMap['is_synced'] == 1,
        );
      }).toList();
      
      Logger.d('SQLiteHelper', 'Retrieved ${attachments.length} attachments for entry: $entryId');
      return attachments;
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error getting attachments for entry: $e');
      // Return empty list as fallback
      return [];
    }
  }
  
  // Habit Methods
  
  // Insert a habit item
  Future<void> insertHabitItem(HabitItem habit) async {
    try {
      final db = await database;
      
      // Convert habit to map
      final Map<String, dynamic> habitMap = {
        'id': habit.id,
        'user_id': habit.userId,
        'title': habit.title,
        'description': habit.description,
        'is_completed': habit.isCompleted ? 1 : 0,
        'created_at': habit.createdAt.toIso8601String(),
        'target_date': habit.targetDate?.toIso8601String(),
        'frequency': habit.frequency,
        'is_synced': habit.isSynced ? 1 : 0,
      };
      
      // Insert habit
      await db.insert(
        tableHabitItems,
        habitMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      Logger.d('SQLiteHelper', 'Inserted habit item: ${habit.id}');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error inserting habit item: $e');
      rethrow;
    }
  }
  
  // Update a habit item
  Future<void> updateHabitItem(HabitItem habit) async {
    try {
      final db = await database;
      
      // Convert habit to map
      final Map<String, dynamic> habitMap = {
        'id': habit.id,
        'user_id': habit.userId,
        'title': habit.title,
        'description': habit.description,
        'is_completed': habit.isCompleted ? 1 : 0,
        'created_at': habit.createdAt.toIso8601String(),
        'target_date': habit.targetDate?.toIso8601String(),
        'frequency': habit.frequency,
        'is_synced': habit.isSynced ? 1 : 0,
      };
      
      // Update habit
      await db.update(
        tableHabitItems,
        habitMap,
        where: 'id = ?',
        whereArgs: [habit.id],
      );
      
      Logger.d('SQLiteHelper', 'Updated habit item: ${habit.id}');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error updating habit item: $e');
      rethrow;
    }
  }
  
  // Delete a habit item
  Future<void> deleteHabitItem(String id) async {
    try {
      final db = await database;
      
      // Delete habit
      await db.delete(
        tableHabitItems,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      Logger.d('SQLiteHelper', 'Deleted habit item: $id');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error deleting habit item: $e');
      rethrow;
    }
  }
  
  // Get all habit items
  Future<List<HabitItem>> getAllHabitItems() async {
    try {
      final db = await database;
      
      // Query habits
      final List<Map<String, dynamic>> habitMaps = await db.query(tableHabitItems);
      
      // Convert to HabitItem objects
      final List<HabitItem> habits = habitMaps.map((habitMap) {
        return HabitItem(
          id: habitMap['id'] as String,
          userId: habitMap['user_id'] as String,
          title: habitMap['title'] as String,
          description: habitMap['description'] as String?,
          isCompleted: habitMap['is_completed'] == 1,
          createdAt: DateTime.parse(habitMap['created_at'] as String),
          targetDate: habitMap['target_date'] != null
              ? DateTime.parse(habitMap['target_date'] as String)
              : null,
          frequency: habitMap['frequency'] as int,
          isSynced: habitMap['is_synced'] == 1,
        );
      }).toList();
      
      Logger.d('SQLiteHelper', 'Retrieved ${habits.length} habit items');
      return habits;
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error getting habit items: $e');
      // Return empty list as fallback
      return [];
    }
  }
  
  // Get unsynced habit items
  Future<List<HabitItem>> getUnsyncedHabitItems() async {
    try {
      final db = await database;
      
      // Query unsynced habits
      final List<Map<String, dynamic>> habitMaps = await db.query(
        tableHabitItems,
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      
      // Convert to HabitItem objects
      final List<HabitItem> habits = habitMaps.map((habitMap) {
        return HabitItem(
          id: habitMap['id'] as String,
          userId: habitMap['user_id'] as String,
          title: habitMap['title'] as String,
          description: habitMap['description'] as String?,
          isCompleted: habitMap['is_completed'] == 1,
          createdAt: DateTime.parse(habitMap['created_at'] as String),
          targetDate: habitMap['target_date'] != null
              ? DateTime.parse(habitMap['target_date'] as String)
              : null,
          frequency: habitMap['frequency'] as int,
          isSynced: habitMap['is_synced'] == 1,
        );
      }).toList();
      
      Logger.d('SQLiteHelper', 'Retrieved ${habits.length} unsynced habit items');
      return habits;
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error getting unsynced habit items: $e');
      // Return empty list as fallback
      return [];
    }
  }
  
  // Database Maintenance Methods
  
  // Check database integrity
  Future<bool> checkDatabaseIntegrity() async {
    try {
      final db = await database;
      
      // Run integrity check
      final List<Map<String, dynamic>> result = await db.rawQuery('PRAGMA integrity_check');
      
      // Check result
      final bool isOk = result.isNotEmpty && 
                result.first.values.first.toString().toLowerCase() == 'ok';
      
      Logger.d('SQLiteHelper', 'Database integrity check: ${isOk ? 'OK' : 'FAILED'}');
      return isOk;
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error checking database integrity: $e');
      return false;
    }
  }
  
  // Vacuum database
  Future<void> vacuumDatabase() async {
    try {
      final db = await database;
      
      // Run vacuum
      await db.execute('VACUUM');
      
      Logger.d('SQLiteHelper', 'Database vacuumed successfully');
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error vacuuming database: $e');
      rethrow;
    }
  }
  
  // Delete database
  Future<void> deleteDatabase() async {
    try {
      // Close database if open
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Get database path
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      
      // Delete database file
      if (await File(path).exists()) {
        await File(path).delete();
        Logger.d('SQLiteHelper', 'Database deleted successfully');
      }
    } catch (e) {
      Logger.e('SQLiteHelper', 'Error deleting database: $e');
      rethrow;
    }
  }
}

// Import HabitItem class
class HabitItem {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? targetDate;
  final int frequency;
  final bool isSynced;

  HabitItem({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.isCompleted = false,
    required this.createdAt,
    this.targetDate,
    this.frequency = 1,
    this.isSynced = false,
  });

  HabitItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? targetDate,
    int? frequency,
    bool? isSynced,
  }) {
    return HabitItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
      frequency: frequency ?? this.frequency,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
