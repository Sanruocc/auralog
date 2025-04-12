import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/sqlite_helper.dart';
import '../models/habit_item.dart';
import '../../../core/utils/logger.dart';

// Create a provider for the SQLite helper to ensure it's initialized only once
final sqliteHelperProvider = Provider<SQLiteHelper>((ref) {
  final sqliteHelper = SQLiteHelper();
  ref.onDispose(() {
    Logger.d('Provider', 'Closing SQLite connection');
    sqliteHelper.close();
  });
  return sqliteHelper;
});

final habitProvider =
    StateNotifierProvider<HabitNotifier, AsyncValue<List<HabitItem>>>((ref) {
  // Get the SQLite helper from the provider
  final sqliteHelper = ref.watch(sqliteHelperProvider);
  
  return HabitNotifier(
    supabase: Supabase.instance.client,
    sqliteHelper: sqliteHelper,
  );
});

class HabitNotifier extends StateNotifier<AsyncValue<List<HabitItem>>> {
  final SupabaseClient supabase;
  final SQLiteHelper sqliteHelper;
  final _uuid = const Uuid();

  HabitNotifier({
    required this.supabase,
    required this.sqliteHelper,
  }) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      Logger.d('HabitNotifier', 'Initializing habit provider');
      
      // Get habits
      try {
        Logger.d('HabitNotifier', 'Loading habits from database');
        final habits = await sqliteHelper.getAllHabitItems();
        Logger.d('HabitNotifier', 'Loaded ${habits.length} habits');
        state = AsyncValue.data(habits);
      } catch (dbError, dbSt) {
        Logger.e('HabitNotifier', 'Error loading habits from database: $dbError');
        // Set empty list as fallback
        state = const AsyncValue.data([]);
      }

      // Try to sync habits but don't fail if it doesn't work
      try {
        Logger.d('HabitNotifier', 'Syncing habits with server');
        await _syncHabits();
      } catch (syncError) {
        Logger.e('HabitNotifier', 'Error syncing habits: $syncError');
        // Continue with initialization even if sync fails
      }

      Logger.d('HabitNotifier', 'Habit provider initialization complete');
    } catch (e, st) {
      Logger.e('HabitNotifier', 'Fatal error during habit provider initialization: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _syncHabits() async {
    try {
      // Get unsynced habits from database
      final unsyncedHabits = await sqliteHelper.getUnsyncedHabitItems();

      // Sync each habit to Supabase
      for (final habit in unsyncedHabits) {
        await supabase.from('habits').upsert({
          'id': habit.id,
          'user_id': habit.userId,
          'title': habit.title,
          'description': habit.description,
          'is_completed': habit.isCompleted,
          'created_at': habit.createdAt.toIso8601String(),
          'target_date': habit.targetDate?.toIso8601String(),
          'frequency': habit.frequency,
        });

        // Update the habit in the database to mark as synced
        final updatedHabit = habit.copyWith(isSynced: true);
        await sqliteHelper.updateHabitItem(updatedHabit);
      }

      // Get habits from server
      final serverHabits = await supabase
          .from('habits')
          .select()
          .order('created_at', ascending: false);

      // Process each server habit
      for (final habitData in serverHabits) {
        final habit = HabitItem(
          id: habitData['id'],
          userId: habitData['user_id'],
          title: habitData['title'],
          description: habitData['description'],
          isCompleted: habitData['is_completed'] ?? false,
          createdAt: DateTime.parse(habitData['created_at']),
          targetDate: habitData['target_date'] != null
              ? DateTime.parse(habitData['target_date'])
              : null,
          frequency: habitData['frequency'] ?? 1,
          isSynced: true,
        );

        // Insert the habit into the database
        await sqliteHelper.insertHabitItem(habit);
      }

      // Refresh state with latest habits
      final habits = await sqliteHelper.getAllHabitItems();
      state = AsyncValue.data(habits);
    } catch (e) {
      // Don't update state on sync error, just log it
      Logger.e('HabitNotifier', 'Sync error: $e');
    }
  }

  Future<void> addHabit({
    required String title,
    String? description,
    DateTime? targetDate,
    int frequency = 1,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final habit = HabitItem(
        id: _uuid.v4(),
        userId: userId,
        title: title,
        description: description,
        createdAt: DateTime.now(),
        targetDate: targetDate,
        frequency: frequency,
        isSynced: false,
      );

      // Insert habit into database
      await sqliteHelper.insertHabitItem(habit);

      // Get all habits and update state
      final habits = await sqliteHelper.getAllHabitItems();
      state = AsyncValue.data(habits);

      // Try to sync immediately
      _syncHabits();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleHabit(String id) async {
    try {
      // Get all habits to find the one to toggle
      final habits = await sqliteHelper.getAllHabitItems();
      final habit = habits.firstWhere(
        (h) => h.id == id,
        orElse: () => throw Exception('Habit not found'),
      );

      // Toggle completion status
      final updatedHabit = habit.copyWith(
        isCompleted: !habit.isCompleted,
        isSynced: false,
      );

      // Update habit in database
      await sqliteHelper.updateHabitItem(updatedHabit);

      // Get all habits and update state
      final updatedHabits = await sqliteHelper.getAllHabitItems();
      state = AsyncValue.data(updatedHabits);

      // Try to sync immediately
      _syncHabits();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      // Delete from database
      await sqliteHelper.deleteHabitItem(id);

      // Delete from Supabase
      await supabase.from('habits').delete().eq('id', id);

      // Get all habits and update state
      final habits = await sqliteHelper.getAllHabitItems();
      state = AsyncValue.data(habits);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Get habits due today
  Future<List<HabitItem>> getDueHabits() async {
    try {
      final allHabits = await sqliteHelper.getAllHabitItems();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return allHabits.where((habit) {
        if (habit.isCompleted) return false;

        // Daily habits are always due
        if (habit.frequency == 1) return true;

        // Weekly habits
        if (habit.frequency == 7) {
          final createdDay = habit.createdAt.weekday;
          return now.weekday == createdDay;
        }

        // Monthly habits
        if (habit.frequency == 30) {
          final createdDate = habit.createdAt.day;
          return now.day == createdDate ||
              (createdDate > DateTime(now.year, now.month + 1, 0).day &&
                  now.day == DateTime(now.year, now.month + 1, 0).day);
        }

        // Target date specific habits
        if (habit.targetDate != null) {
          final targetDay = DateTime(
            habit.targetDate!.year,
            habit.targetDate!.month,
            habit.targetDate!.day,
          );
          return targetDay.isAtSameMomentAs(today);
        }

        return false;
      }).toList();
    } catch (e) {
      Logger.e('HabitNotifier', 'Error getting due habits: $e');
      return [];
    }
  }
}
