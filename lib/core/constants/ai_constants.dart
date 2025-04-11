import '../../features/journal/models/journal_entry.dart';

class AIPredefinedPrompts {
  static String sentimentAnalysisPrompt(String content) {
    return '''
    Analyze the sentiment of the following journal entry. Return only one word: "positive", "negative", or "neutral".
    
    Journal entry: "$content"
    ''';
  }

  static String entrySummaryPrompt(JournalEntry entry) {
    return '''
    Summarize the following journal entry in 2-3 concise sentences that capture the key emotions and main points.
    The mood the person selected was: ${entry.mood.label}.
    
    Journal entry: "${entry.content}"
    ''';
  }

  static String weeklySummaryPrompt(List<JournalEntry> entries) {
    final entriesText = entries
        .map((e) =>
            "Date: ${_formatDate(e.createdAt)}, Mood: ${e.mood.label}, Entry: ${e.content}")
        .join("\n\n");

    return '''
    Create a weekly reflection summary based on these journal entries. 
    Include patterns in mood, significant events, and suggestions for the coming week.
    Keep it to 4-5 sentences maximum, compassionate in tone, and personalized.
    
    Entries:
    $entriesText
    ''';
  }

  static String monthlySummaryPrompt(List<JournalEntry> entries) {
    final entriesText = entries
        .map((e) =>
            "Date: ${_formatDate(e.createdAt)}, Mood: ${e.mood.label}, Entry: ${e.content}")
        .join("\n\n");

    return '''
    Create a monthly reflection summary based on these journal entries.
    Identify important themes, mood patterns, achievements, and areas for growth.
    Keep it to 5-6 sentences maximum, encouraging in tone, and personalized.
    
    Entries:
    $entriesText
    ''';
  }

  static String personalizedInsightsPrompt(List<JournalEntry> entries) {
    final entriesText = entries
        .map((e) =>
            "Date: ${_formatDate(e.createdAt)}, Mood: ${e.mood.label}, Entry: ${e.content}")
        .join("\n\n");

    return '''
    Based on these journal entries, provide 3 personalized psychological insights that might help the person 
    understand their thoughts, feelings, and behaviors better. These should be compassionate, specific to the content, 
    and focused on growth. Keep total response under 4 sentences.
    
    Entries:
    $entriesText
    ''';
  }

  static String affirmationsPrompt(List<JournalEntry> entries) {
    final entriesText = entries
        .map((e) =>
            "Date: ${_formatDate(e.createdAt)}, Mood: ${e.mood.label}, Entry: ${e.content}")
        .join("\n\n");

    return '''
    Based on these journal entries, create 3 personalized affirmations that would resonate with the writer.
    Make them specific to their experiences, challenges, and strengths revealed in their writing.
    
    Entries:
    $entriesText
    ''';
  }

  static String dynamicPromptGeneration(List<JournalEntry> recentEntries) {
    final entriesText = recentEntries
        .map((e) =>
            "Date: ${_formatDate(e.createdAt)}, Mood: ${e.mood.label}, Entry: ${e.content}")
        .join("\n\n");

    return '''
    Based on these recent journal entries, create one thoughtful journaling prompt that would help the person 
    explore their thoughts and feelings more deeply. Make it relevant to themes in their writing,
    but also encouraging personal growth. The prompt should be 1-2 sentences only.
    
    Recent entries:
    $entriesText
    ''';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}
