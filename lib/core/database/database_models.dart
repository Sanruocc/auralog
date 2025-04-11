import '../../features/journal/models/journal_entry.dart';
import '../../features/habits/models/habit_item.dart';

// Database models for Drift
class DbJournalEntry {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final Mood mood;
  final Sentiment? sentiment;
  final bool isSynced;
  final String? summary;

  DbJournalEntry({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.mood,
    this.sentiment,
    this.isSynced = false,
    this.summary,
  });

  // Convert to domain model
  JournalEntry toDomain({List<Attachment> attachments = const []}) {
    return JournalEntry(
      id: id,
      userId: userId,
      content: content,
      createdAt: createdAt,
      mood: mood,
      sentiment: sentiment,
      isSynced: isSynced,
      summary: summary,
      attachments: attachments,
    );
  }

  // Create from domain model
  factory DbJournalEntry.fromDomain(JournalEntry entry) {
    return DbJournalEntry(
      id: entry.id,
      userId: entry.userId,
      content: entry.content,
      createdAt: entry.createdAt,
      mood: entry.mood,
      sentiment: entry.sentiment,
      isSynced: entry.isSynced,
      summary: entry.summary,
    );
  }
}

class DbAttachment {
  final String id;
  final String entryId;
  final AttachmentType type;
  final String url;
  final DateTime createdAt;
  final bool isSynced;

  DbAttachment({
    required this.id,
    required this.entryId,
    required this.type,
    required this.url,
    required this.createdAt,
    this.isSynced = false,
  });

  // Convert to domain model
  Attachment toDomain() {
    return Attachment(
      id: id,
      entryId: entryId,
      type: type,
      url: url,
      createdAt: createdAt,
      isSynced: isSynced,
    );
  }

  // Create from domain model
  factory DbAttachment.fromDomain(Attachment attachment) {
    return DbAttachment(
      id: attachment.id,
      entryId: attachment.entryId,
      type: attachment.type,
      url: attachment.url,
      createdAt: attachment.createdAt,
      isSynced: attachment.isSynced,
    );
  }
}

class DbHabitItem {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? targetDate;
  final int frequency;
  final bool isSynced;

  DbHabitItem({
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

  // Convert to domain model
  HabitItem toDomain() {
    return HabitItem(
      id: id,
      userId: userId,
      title: title,
      description: description,
      isCompleted: isCompleted,
      createdAt: createdAt,
      targetDate: targetDate,
      frequency: frequency,
      isSynced: isSynced,
    );
  }

  // Create from domain model
  factory DbHabitItem.fromDomain(HabitItem habit) {
    return DbHabitItem(
      id: habit.id,
      userId: habit.userId,
      title: habit.title,
      description: habit.description,
      isCompleted: habit.isCompleted,
      createdAt: habit.createdAt,
      targetDate: habit.targetDate,
      frequency: habit.frequency,
      isSynced: habit.isSynced,
    );
  }
}
