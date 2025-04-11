import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_item.dart';
import '../providers/habit_provider.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker'),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(
              child: Text('No habits yet. Create one by tapping the + button.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _buildHabitCard(habit);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHabitDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHabitCard(HabitItem habit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: IconButton(
          icon: Icon(
            habit.isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: habit.isCompleted ? Colors.green : Colors.grey,
            size: 28,
          ),
          onPressed: () =>
              ref.read(habitProvider.notifier).toggleHabit(habit.id),
        ),
        title: Text(
          habit.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            decoration: habit.isCompleted ? TextDecoration.lineThrough : null,
            color: habit.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (habit.description != null && habit.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(habit.description!),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _getFrequencyText(habit),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(habit),
        ),
      ),
    );
  }

  String _getFrequencyText(HabitItem habit) {
    if (habit.frequency == 1) {
      return 'Daily';
    } else if (habit.frequency == 7) {
      return 'Weekly';
    } else if (habit.frequency == 30) {
      return 'Monthly';
    } else if (habit.targetDate != null) {
      return 'Target: ${_formatDate(habit.targetDate!)}';
    } else {
      return 'Custom: Every ${habit.frequency} days';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _confirmDelete(HabitItem habit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to delete "${habit.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(habitProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String description = '';
    int frequency = 1;
    DateTime? targetDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Habit'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'What habit do you want to track?',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                    onChanged: (value) => title = value,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Add details about this habit',
                    ),
                    onChanged: (value) => description = value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                    ),
                    value: frequency,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Daily')),
                      DropdownMenuItem(value: 7, child: Text('Weekly')),
                      DropdownMenuItem(value: 30, child: Text('Monthly')),
                      DropdownMenuItem(value: 0, child: Text('Specific Date')),
                    ],
                    onChanged: (value) {
                      frequency = value ?? 1;
                    },
                  ),
                  if (frequency == 0) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          targetDate = date;
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Target Date',
                            hintText: 'When do you want to complete this?',
                          ),
                          controller: TextEditingController(
                            text: targetDate != null
                                ? _formatDate(targetDate!)
                                : '',
                          ),
                          validator: (value) {
                            if (frequency == 0 && targetDate == null) {
                              return 'Please select a target date';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  ref.read(habitProvider.notifier).addHabit(
                        title: title,
                        description: description.isEmpty ? null : description,
                        targetDate: targetDate,
                        frequency: frequency,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
