import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';

class MoodCalendarScreen extends ConsumerStatefulWidget {
  const MoodCalendarScreen({super.key});

  @override
  ConsumerState<MoodCalendarScreen> createState() => _MoodCalendarScreenState();
}

class _MoodCalendarScreenState extends ConsumerState<MoodCalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final journalState = ref.watch(journalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Calendar'),
      ),
      body: journalState.when(
        data: (entries) {
          // Create a map of entries by date for the calendar
          final Map<DateTime, List<JournalEntry>> entriesByDate = {};
          for (var entry in entries) {
            final date = DateTime(
              entry.createdAt.year,
              entry.createdAt.month,
              entry.createdAt.day,
            );
            if (entriesByDate[date] == null) entriesByDate[date] = [];
            entriesByDate[date]!.add(entry);
          }

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final dayEntries = entriesByDate[DateTime(
                      date.year,
                      date.month,
                      date.day,
                    )];

                    if (dayEntries == null || dayEntries.isEmpty) {
                      return null;
                    }

                    // Find the dominant mood of the day (simple approach)
                    Mood dominantMood = Mood.okay; // Default
                    if (dayEntries.isNotEmpty) {
                      dominantMood = dayEntries.first.mood;
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 20),
                      alignment: Alignment.center,
                      child: Text(
                        dominantMood.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _selectedDayEntries(entriesByDate),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
    );
  }

  Widget _selectedDayEntries(Map<DateTime, List<JournalEntry>> entriesByDate) {
    final selectedDate = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final dayEntries = entriesByDate[selectedDate] ?? [];

    if (dayEntries.isEmpty) {
      return const Center(
        child: Text('No entries for this day'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayEntries.length,
      itemBuilder: (context, index) {
        final entry = dayEntries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.mood.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.mood.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (entry.sentiment != null)
                      Text(
                        entry.sentiment!.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(entry.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
