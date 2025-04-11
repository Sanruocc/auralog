enum Sentiment {
  positive,
  negative,
  neutral;

  String get emoji {
    switch (this) {
      case Sentiment.positive:
        return '😊';
      case Sentiment.negative:
        return '😔';
      case Sentiment.neutral:
        return '😐';
    }
  }
}

enum Mood {
  great('Great', '🤩'),
  good('Good', '😊'),
  okay('Okay', '😐'),
  bad('Bad', '😕'),
  terrible('Terrible', '😢');

  final String label;
  final String emoji;
  const Mood(this.label, this.emoji);
}

enum AttachmentType {
  photo,
  voice;

  String get extension {
    switch (this) {
      case AttachmentType.photo:
        return '.jpg';
      case AttachmentType.voice:
        return '.m4a';
    }
  }
}

class Attachment {
  final String id;
  final String entryId;
  final AttachmentType type;
  final String url;
  final DateTime createdAt;
  final bool isSynced;

  const Attachment({
    required this.id,
    required this.entryId,
    required this.type,
    required this.url,
    required this.createdAt,
    this.isSynced = false,
  });

  Attachment copyWith({
    String? id,
    String? entryId,
    AttachmentType? type,
    String? url,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return Attachment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      type: type ?? this.type,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_id': entryId,
      'type': type.name,
      'url': url,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      type: AttachmentType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AttachmentType.photo,
      ),
      url: json['url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: json['is_synced'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Attachment &&
        other.id == id &&
        other.entryId == entryId &&
        other.type == type &&
        other.url == url &&
        other.createdAt == createdAt &&
        other.isSynced == isSynced;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      entryId,
      type,
      url,
      createdAt,
      isSynced,
    );
  }
}

class JournalEntry {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final Mood mood;
  final Sentiment? sentiment;
  final bool isSynced;
  final List<Attachment> attachments;
  final String? summary;

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.mood,
    this.sentiment,
    this.isSynced = false,
    this.attachments = const [],
    this.summary,
  });

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? content,
    DateTime? createdAt,
    Mood? mood,
    Sentiment? sentiment,
    bool? isSynced,
    List<Attachment>? attachments,
    String? summary,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      mood: mood ?? this.mood,
      sentiment: sentiment ?? this.sentiment,
      isSynced: isSynced ?? this.isSynced,
      attachments: attachments ?? this.attachments,
      summary: summary ?? this.summary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'mood': mood.name,
      'sentiment': sentiment?.name,
      'is_synced': isSynced,
      'summary': summary,
      // Attachments are handled separately
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mood: Mood.values.firstWhere(
        (m) => m.name == json['mood'],
        orElse: () => Mood.okay,
      ),
      sentiment: json['sentiment'] != null
          ? Sentiment.values.firstWhere(
              (s) => s.name == json['sentiment'],
              orElse: () => Sentiment.neutral,
            )
          : null,
      isSynced: json['is_synced'] as bool? ?? false,
      summary: json['summary'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JournalEntry &&
        other.id == id &&
        other.userId == userId &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.mood == mood &&
        other.sentiment == sentiment &&
        other.isSynced == isSynced &&
        other.summary == summary;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      content,
      createdAt,
      mood,
      sentiment,
      isSynced,
      summary,
    );
  }
}
