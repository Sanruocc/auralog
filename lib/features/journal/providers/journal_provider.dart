import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/sqlite_helper.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/logger.dart';
import '../models/journal_entry.dart';

// Create a provider for the SQLite helper to ensure it's initialized only once
final sqliteHelperProvider = Provider<SQLiteHelper>((ref) {
  final sqliteHelper = SQLiteHelper();
  ref.onDispose(() {
    Logger.d('Provider', 'Closing SQLite connection');
    sqliteHelper.close();
  });
  return sqliteHelper;
});

final journalProvider =
    StateNotifierProvider<JournalNotifier, AsyncValue<List<JournalEntry>>>(
        (ref) {
  // Get the SQLite helper from the provider
  final sqliteHelper = ref.watch(sqliteHelperProvider);
  
  return JournalNotifier(
    supabase: Supabase.instance.client,
    sqliteHelper: sqliteHelper,
    aiService: AIService(),
    storageService: StorageService(),
  );
});

class JournalNotifier extends StateNotifier<AsyncValue<List<JournalEntry>>> {
  final SupabaseClient supabase;
  final SQLiteHelper sqliteHelper;
  final AIService aiService;
  final StorageService storageService;
  final _uuid = const Uuid();

  JournalNotifier({
    required this.supabase,
    required this.sqliteHelper,
    required this.aiService,
    required this.storageService,
  }) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      Logger.d('JournalNotifier', 'Initializing journal provider');
      
      // Get entries with attachments
      try {
        Logger.d('JournalNotifier', 'Loading journal entries from database');
        final entries = await sqliteHelper.getAllJournalEntries();
        Logger.d('JournalNotifier', 'Loaded ${entries.length} journal entries');
        state = AsyncValue.data(entries);
      } catch (dbError, dbSt) {
        Logger.e(
            'JournalNotifier', 'Error loading entries from database: $dbError');
        debugPrintStack(stackTrace: dbSt);
        // Set empty list as fallback
        state = const AsyncValue.data([]);
      }

      // Try to sync entries but don't fail if it doesn't work
      try {
        Logger.d('JournalNotifier', 'Syncing entries with server');
        await _syncEntries();
      } catch (syncError) {
        Logger.e('JournalNotifier', 'Error syncing entries: $syncError');
        // Continue with initialization even if sync fails
      }

      // Initialize storage bucket if needed
      try {
        Logger.d('JournalNotifier', 'Initializing storage bucket');
        await storageService.initStorage();
      } catch (storageError) {
        Logger.e(
            'JournalNotifier', 'Error initializing storage: $storageError');
        // Continue with initialization even if storage init fails
      }

      Logger.d('JournalNotifier', 'Journal provider initialization complete');
    } catch (e, st) {
      Logger.e('JournalNotifier',
          'Fatal error during journal provider initialization: $e');
      debugPrintStack(stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _syncEntries() async {
    try {
      // Get unsynced entries from database
      final unsyncedEntries = await sqliteHelper.getUnsyncedJournalEntries();

      // Sync each entry to Supabase
      for (final entry in unsyncedEntries) {
        await supabase.from('journal_entries').upsert(entry.toJson());

        // Sync attachments if any
        for (final attachment in entry.attachments) {
          if (!attachment.isSynced) {
            await supabase.from('attachments').upsert(attachment.toJson());
          }
        }

        // Update the entry in the database to mark as synced
        final updatedEntry = entry.copyWith(isSynced: true);
        await sqliteHelper.updateJournalEntry(updatedEntry);
      }

      // Get entries from server
      final serverEntries = await supabase
          .from('journal_entries')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      // Process each server entry
      for (final entryData in serverEntries) {
        final domainEntry = JournalEntry.fromJson(entryData);

        // Fetch attachments for this entry
        final attachmentsData = await supabase
            .from('attachments')
            .select()
            .eq('entry_id', domainEntry.id);

        final attachments =
            attachmentsData.map((data) => Attachment.fromJson(data)).toList();

        // Create a complete entry with attachments
        final completeEntry = domainEntry.copyWith(
          attachments: attachments,
          isSynced: true,
        );

        // Insert the entry into the database
        await sqliteHelper.insertJournalEntry(completeEntry);
      }

      // Refresh state with latest entries
      final entries = await sqliteHelper.getAllJournalEntries();
      state = AsyncValue.data(entries);
    } catch (e) {
      // Don't update state on sync error, just log it
      Logger.e('JournalNotifier', 'Sync error: $e');
    }
  }

  Future<void> addEntry({
    required String content,
    required Mood mood,
    List<File> photoFiles = const [],
    File? voiceFile,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Create entry ID first
      final entryId = _uuid.v4();

      // Process sentiment analysis
      final sentiment = await aiService.analyzeSentiment(content);

      // Generate a summary using AI if content is long enough
      String? summary;
      if (content.length > 200) {
        try {
          final tempEntry = JournalEntry(
            id: entryId,
            userId: userId,
            content: content,
            createdAt: DateTime.now(),
            mood: mood,
            sentiment: sentiment,
          );
          summary = await aiService.generateEntrySummary(tempEntry);
        } catch (e) {
          Logger.e('JournalNotifier', 'Error generating summary: $e');
        }
      }

      // Upload attachments
      final attachments = <Attachment>[];

      // Process photo attachments
      for (final photoFile in photoFiles) {
        try {
          final url = await storageService.uploadAttachment(
            file: photoFile,
            userId: userId,
            entryId: entryId,
            type: AttachmentType.photo,
          );

          attachments.add(Attachment(
            id: _uuid.v4(),
            entryId: entryId,
            type: AttachmentType.photo,
            url: url,
            createdAt: DateTime.now(),
            isSynced: false,
          ));
        } catch (e) {
          Logger.e('JournalNotifier', 'Error uploading photo: $e');
        }
      }

      // Process voice attachment
      if (voiceFile != null) {
        try {
          final url = await storageService.uploadAttachment(
            file: voiceFile,
            userId: userId,
            entryId: entryId,
            type: AttachmentType.voice,
          );

          attachments.add(Attachment(
            id: _uuid.v4(),
            entryId: entryId,
            type: AttachmentType.voice,
            url: url,
            createdAt: DateTime.now(),
            isSynced: false,
          ));
        } catch (e) {
          Logger.e('JournalNotifier', 'Error uploading voice note: $e');
        }
      }

      // Create domain model entry
      final domainEntry = JournalEntry(
        id: entryId,
        userId: userId,
        content: content,
        createdAt: DateTime.now(),
        mood: mood,
        sentiment: sentiment,
        summary: summary,
        attachments: attachments,
        isSynced: false,
      );

      // Insert entry into database
      await sqliteHelper.insertJournalEntry(domainEntry);

      // Get all entries and update state
      final entries = await sqliteHelper.getAllJournalEntries();
      state = AsyncValue.data(entries);

      // Try to sync immediately
      _syncEntries();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      // Get all entries to find the one to delete
      final entries = await sqliteHelper.getAllJournalEntries();
      final entry = entries.firstWhere(
        (e) => e.id == id,
        orElse: () => throw Exception('Entry not found'),
      );

      // Delete attachments from storage
      for (final attachment in entry.attachments) {
        try {
          final fileName = attachment.url.split('/').last;
          await storageService.deleteAttachment(
            userId: entry.userId,
            entryId: entry.id,
            type: attachment.type,
            fileName: fileName,
          );
        } catch (e) {
          Logger.e('JournalNotifier', 'Error deleting attachment: $e');
        }
      }

      // Delete from database
      await sqliteHelper.deleteJournalEntry(id);

      // Delete from Supabase
      await supabase.from('attachments').delete().eq('entry_id', id);
      await supabase.from('journal_entries').delete().eq('id', id);

      // Get all entries and update state
      final updatedEntries = await sqliteHelper.getAllJournalEntries();
      state = AsyncValue.data(updatedEntries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<JournalEntry>> getEntriesForPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final entries = await sqliteHelper.getAllJournalEntries();

      // Filter entries by date
      final filteredEntries = entries.where((entry) {
        return entry.createdAt.isAfter(startDate) &&
            entry.createdAt.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      return filteredEntries;
    } catch (e) {
      Logger.e('JournalNotifier', 'Error fetching entries for period: $e');
      return [];
    }
  }

  Future<String> generateWeeklySummary(DateTime weekStart) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final entries = await getEntriesForPeriod(
        startDate: weekStart,
        endDate: weekEnd,
      );

      if (entries.isEmpty) {
        return "No journal entries found for this week.";
      }

      return await aiService.generateWeeklySummary(entries);
    } catch (e) {
      Logger.e('JournalNotifier', 'Error generating weekly summary: $e');
      return "Unable to generate weekly summary at this time.";
    }
  }

  Future<String> generateMonthlySummary(DateTime monthStart) async {
    try {
      // Calculate month end (this is approximate)
      final monthEnd = DateTime(
        monthStart.year,
        monthStart.month + 1,
        0,
      );

      final entries = await getEntriesForPeriod(
        startDate: monthStart,
        endDate: monthEnd,
      );

      if (entries.isEmpty) {
        return "No journal entries found for this month.";
      }

      return await aiService.generateMonthlySummary(entries);
    } catch (e) {
      Logger.e('JournalNotifier', 'Error generating monthly summary: $e');
      return "Unable to generate monthly summary at this time.";
    }
  }

  Future<String> generatePersonalizedInsights() async {
    try {
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final entries = await getEntriesForPeriod(
        startDate: twoWeeksAgo,
        endDate: now,
      );

      if (entries.isEmpty) {
        return "Write more journal entries to get personalized insights.";
      }

      return await aiService.generatePersonalizedInsights(entries);
    } catch (e) {
      Logger.e('JournalNotifier', 'Error generating insights: $e');
      return "Unable to generate insights at this time.";
    }
  }

  Future<String> generateAffirmations() async {
    try {
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final entries = await getEntriesForPeriod(
        startDate: twoWeeksAgo,
        endDate: now,
      );

      if (entries.isEmpty) {
        return "Write more journal entries to get personalized affirmations.";
      }

      return await aiService.generateAffirmations(entries);
    } catch (e) {
      Logger.e('JournalNotifier', 'Error generating affirmations: $e');
      return "Unable to generate affirmations at this time.";
    }
  }

  Future<String> generateDynamicPrompt() async {
    try {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      final entries = await getEntriesForPeriod(
        startDate: oneWeekAgo,
        endDate: now,
      );

      if (entries.isEmpty) {
        return "What's on your mind today?";
      }

      return await aiService.generateDynamicPrompt(entries);
    } catch (e) {
      Logger.e('JournalNotifier', 'Error generating prompt: $e');
      return "What's on your mind today?";
    }
  }
}
