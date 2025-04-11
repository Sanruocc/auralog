import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../../features/journal/models/journal_entry.dart';

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

// Provider for analyzing sentiment of a journal entry
final sentimentAnalysisProvider =
    FutureProvider.family<Sentiment, String>((ref, content) async {
  final aiService = ref.watch(aiServiceProvider);
  return aiService.analyzeSentiment(content);
});

// Provider for generating a summary for a specific journal entry
final entrySummaryProvider =
    FutureProvider.family<String, JournalEntry>((ref, entry) async {
  final aiService = ref.watch(aiServiceProvider);
  return aiService.generateEntrySummary(entry);
});

// Provider for weekly summary
final weeklySummaryProvider =
    FutureProvider.family<String, List<JournalEntry>>((ref, entries) async {
  final aiService = ref.watch(aiServiceProvider);
  return aiService.generateWeeklySummary(entries);
});

// Provider for monthly summary
final monthlySummaryProvider =
    FutureProvider.family<String, List<JournalEntry>>((ref, entries) async {
  final aiService = ref.watch(aiServiceProvider);
  return aiService.generateMonthlySummary(entries);
});

// Provider for personalized insights
final personalizedInsightsProvider =
    FutureProvider.family<String, List<JournalEntry>>((ref, entries) async {
  final aiService = ref.watch(aiServiceProvider);
  return aiService.generatePersonalizedInsights(entries);
});

// Provider for personalized affirmations
final affirmationsProvider =
    FutureProvider.family<String, List<JournalEntry>>((ref, entries) async {
  final aiService = ref.watch(aiServiceProvider);
  return aiService.generateAffirmations(entries);
});

// Provider for dynamic journal prompts
final dynamicPromptProvider = FutureProvider.family<String, List<JournalEntry>>(
    (ref, recentEntries) async {
  final aiService = ref.watch(aiServiceProvider);
  return aiService.generateDynamicPrompt(recentEntries);
});
