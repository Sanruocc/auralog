import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart' as db;
import '../models/habit_item.dart';
import '../../../core/utils/logger.dart';


final habitProvider =
    StateNotifierProvider<HabitNotifier, AsyncValue<List<HabitItem>>>((ref) {
  return HabitNotifier(
    supabase: Supabase.instance.client,
    database: db.AppDatabase(),
  );
});

class HabitNotifier extends StateNotifier<AsyncValue<List<HabitItem>>> {
  final SupabaseClient supabase;
  final db.AppDatabase database;
  final _uuid = const Uuid();

  HabitNotifier({
    required this.supabase,
    required this.database,
  }) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final habits = await database.getAllHabits();
      state = AsyncValue.data(habits.map((h) => HabitItem.fromJson(h.toJson())).toList());
      _syncHabits();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _syncHabits() async {
    try {
      final unsyncedHabits = await database.getUnsyncedHabits();
      for (final habit in unsyncedHabits) {
        await supabase.from('habits').upsert(habit.toJson());
        await database.updateHabit(habit.copyWith(isSynced: true));
      }

      final serverHabits = await supabase
          .from('habits')
          .select()
          .order('created_at', ascending: false);

      for (final habitData in serverHabits) {
        final modelHabit = HabitItem.fromJson(habitData);
        await database.insertHabit(db.HabitItem(
          id: modelHabit.id,
          userId: modelHabit.userId,
          title: modelHabit.title,
          description: modelHabit.description,
          isCompleted: modelHabit.isCompleted,
          createdAt: modelHabit.createdAt,
          targetDate: modelHabit.targetDate,
          frequency: modelHabit.frequency,
          isSynced: modelHabit.isSynced,
        ));
      }

      final allHabits = await database.getAllHabits();
      state = AsyncValue.data(allHabits.map((h) => HabitItem.fromJson(h.toJson())).toList());
    } catch (e) {
      // Don't update state on sync error, just log it
      Logger.e('HabitProvider', 'Sync error: $e');
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

      await database.insertHabit(db.HabitItem(
        id: habit.id,
        userId: habit.userId,
        title: habit.title,
        description: habit.description,
        isCompleted: habit.isCompleted,
        createdAt: habit.createdAt,
        targetDate: habit.targetDate,
        frequency: habit.frequency,
        isSynced: habit.isSynced,
      ));

      final habits = await database.getAllHabits();
      state = AsyncValue.data(habits.map((h) => HabitItem.fromJson(h.toJson())).toList());

      // Try to sync immediately
      _syncHabits();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleHabit(String id) async {
    try {
      final habits = await database.getAllHabits();
      final habit = habits.firstWhere(
        (h) => h.id == id,
        orElse: () => throw Exception('Habit not found'),
      );

      final updatedHabit = habit.copyWith(
        isCompleted: !habit.isCompleted,
        isSynced: false,
      );

      await database.updateHabit(updatedHabit);

      final updatedHabits = await database.getAllHabits();
      state = AsyncValue.data(updatedHabits.map((h) => HabitItem.fromJson(h.toJson())).toList());

      // Try to sync immediately
      _syncHabits();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await database.deleteHabit(id);
      await supabase.from('habits').delete().eq('id', id);

      final habits = await database.getAllHabits();
      state = AsyncValue.data(habits.map((h) => HabitItem.fromJson(h.toJson())).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Get habits due today
  Future<List<HabitItem>> getDueHabits() async {
    try {
      final allHabitsDb = await database.getAllHabits();
      final allHabits = allHabitsDb.map((h) => HabitItem.fromJson(h.toJson())).toList();
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
      Logger.e('HabitProvider', 'Error getting due habits: $e');
      return [];
    }
  }

}
