import 'package:drift/drift.dart';
import '../../features/journal/models/journal_entry.dart' as journal_model;
import 'database_connection.dart';

part 'database.g.dart';

class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get mood => textEnum<journal_model.Mood>()();
  TextColumn get sentiment => textEnum<journal_model.Sentiment>().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get summary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(JournalEntries, #id)();
  TextColumn get type => textEnum<journal_model.AttachmentType>()();
  TextColumn get url => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class HabitItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get frequency =>
      integer().withDefault(const Constant(1))(); // 1: daily, 7: weekly, etc.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [JournalEntries, Attachments, HabitItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) {
        return m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add summary column to journal_entries
          await m.addColumn(journalEntries, journalEntries.summary);
          // Create attachments and habit_items tables
          await m.createTable(attachments);
          await m.createTable(habitItems);
        }
      },
    );
  }

  // Journal Entry methods - removed to avoid confusion

  // Renamed to avoid confusion with domain model
  Future<List<journal_model.JournalEntry>> getAllEntries() async {
    return getAllEntriesWithAttachments();
  }

  // Get all journal entries with attachments
  Future<List<journal_model.JournalEntry>>
      getAllEntriesWithAttachments() async {
    final entries = await select(journalEntries).get();
    final result = <journal_model.JournalEntry>[];

    for (final entry in entries) {
      final query = select(attachments);
      query.where((a) => a.entryId.equals(entry.id));
      final attachmentRows = await query.get();

      final attachmentsList = attachmentRows
          .map((a) => journal_model.Attachment(
                id: a.id,
                entryId: a.entryId,
                type: a.type,
                url: a.url,
                createdAt: a.createdAt,
                isSynced: a.isSynced,
              ))
          .toList();

      result.add(journal_model.JournalEntry(
        id: entry.id,
        userId: entry.userId,
        content: entry.content,
        createdAt: entry.createdAt,
        mood: entry.mood,
        sentiment: entry.sentiment,
        isSynced: entry.isSynced,
        summary: entry.summary,
        attachments: attachmentsList,
      ));
    }

    return result;
  }

  // Get attachments for a specific entry (database model) - removed to avoid confusion

  // Get attachments for a specific entry (domain model)
  Future<List<journal_model.Attachment>> getAttachmentsForEntry(
      String entryId) async {
    final query = select(attachments);
    query.where((a) => a.entryId.equals(entryId));
    final dbAttachments = await query.get();
    return dbAttachments
        .map((a) => journal_model.Attachment(
              id: a.id,
              entryId: a.entryId,
              type: a.type,
              url: a.url,
              createdAt: a.createdAt,
              isSynced: a.isSynced,
            ))
        .toList();
  }

  Future<void> insertEntry(journal_model.JournalEntry entry) async {
    await transaction(() async {
      // Insert entry
      await into(journalEntries).insert(
        JournalEntriesCompanion.insert(
          id: entry.id,
          userId: entry.userId,
          content: entry.content,
          createdAt: entry.createdAt,
          mood: entry.mood,
          sentiment: Value(entry.sentiment),
          isSynced: Value(entry.isSynced),
          summary: Value(entry.summary),
        ),
      );

      // Insert attachments
      for (final attachment in entry.attachments) {
        await into(attachments).insert(
          AttachmentsCompanion.insert(
            id: attachment.id,
            entryId: attachment.entryId,
            type: attachment.type,
            url: attachment.url,
            createdAt: attachment.createdAt,
            isSynced: Value(attachment.isSynced),
          ),
        );
      }
    });
  }

  Future<void> updateEntry(journal_model.JournalEntry entry) async {
    await transaction(() async {
      // Update entry
      await update(journalEntries).replace(
        JournalEntriesCompanion(
          id: Value(entry.id),
          userId: Value(entry.userId),
          content: Value(entry.content),
          createdAt: Value(entry.createdAt),
          mood: Value(entry.mood),
          sentiment: Value(entry.sentiment),
          isSynced: Value(entry.isSynced),
          summary: Value(entry.summary),
        ),
      );

      // Handle attachments (delete and re-insert)
      await (delete(attachments)..where((a) => a.entryId.equals(entry.id)))
          .go();

      for (final attachment in entry.attachments) {
        await into(attachments).insert(
          AttachmentsCompanion.insert(
            id: attachment.id,
            entryId: attachment.entryId,
            type: attachment.type,
            url: attachment.url,
            createdAt: attachment.createdAt,
            isSynced: Value(attachment.isSynced),
          ),
        );
      }
    });
  }

  Future<void> deleteEntry(String id) async {
    await transaction(() async {
      // Delete attachments first (foreign key constraint)
      await (delete(attachments)..where((a) => a.entryId.equals(id))).go();
      // Delete entry
      await (delete(journalEntries)..where((e) => e.id.equals(id))).go();
    });
  }

  Future<List<journal_model.JournalEntry>> getUnsyncedEntries() async {
    final entries = await (select(journalEntries)
          ..where((e) => e.isSynced.equals(false)))
        .get();
    final result = <journal_model.JournalEntry>[];

    for (final entry in entries) {
      final attachmentRows = await (select(attachments)
            ..where((a) => a.entryId.equals(entry.id)))
          .get();

      final attachmentsList = attachmentRows
          .map((a) => journal_model.Attachment(
                id: a.id,
                entryId: a.entryId,
                type: a.type,
                url: a.url,
                createdAt: a.createdAt,
                isSynced: a.isSynced,
              ))
          .toList();

      result.add(journal_model.JournalEntry(
        id: entry.id,
        userId: entry.userId,
        content: entry.content,
        createdAt: entry.createdAt,
        mood: entry.mood,
        sentiment: entry.sentiment,
        isSynced: entry.isSynced,
        summary: entry.summary,
        attachments: attachmentsList,
      ));
    }

    return result;
  }

  // Habit Tracker methods
  Future<List<HabitItem>> getAllHabits() async {
    final habits = await select(habitItems).get();
    return habits
        .map((row) => HabitItem(
              id: row.id,
              userId: row.userId,
              title: row.title,
              description: row.description,
              isCompleted: row.isCompleted,
              createdAt: row.createdAt,
              targetDate: row.targetDate,
              frequency: row.frequency,
              isSynced: row.isSynced,
            ))
        .toList();
  }

  Future<void> insertHabit(HabitItem habit) async {
    await into(habitItems).insert(
      HabitItemsCompanion.insert(
        id: habit.id,
        userId: habit.userId,
        title: habit.title,
        description: Value(habit.description),
        isCompleted: Value(habit.isCompleted),
        createdAt: habit.createdAt,
        targetDate: Value(habit.targetDate),
        frequency: Value(habit.frequency),
        isSynced: Value(habit.isSynced),
      ),
    );
  }

  Future<void> updateHabit(HabitItem habit) async {
    await update(habitItems).replace(
      HabitItemsCompanion(
        id: Value(habit.id),
        userId: Value(habit.userId),
        title: Value(habit.title),
        description: Value(habit.description),
        isCompleted: Value(habit.isCompleted),
        createdAt: Value(habit.createdAt),
        targetDate: Value(habit.targetDate),
        frequency: Value(habit.frequency),
        isSynced: Value(habit.isSynced),
      ),
    );
  }

  Future<void> deleteHabit(String id) async {
    await (delete(habitItems)..where((h) => h.id.equals(id))).go();
  }

  Future<List<HabitItem>> getUnsyncedHabits() async {
    final habits = await (select(habitItems)
          ..where((h) => h.isSynced.equals(false)))
        .get();
    return habits
        .map((row) => HabitItem(
              id: row.id,
              userId: row.userId,
              title: row.title,
              description: row.description,
              isCompleted: row.isCompleted,
              createdAt: row.createdAt,
              targetDate: row.targetDate,
              frequency: row.frequency,
              isSynced: row.isSynced,
            ))
        .toList();
  }
}

// Database connection is defined in database_connection.dart
