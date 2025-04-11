import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/ai_constants.dart';
import '../../features/journal/models/journal_entry.dart';
import '../utils/logger.dart';

class AIService {
  // Fallback key for development environments
  static const String _fallbackApiKey =
      'AIzaSyAJA1Rqdh_5WOD4abe0a4PjqGr9WApq4FQ';

  final String apiKey;
  final String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  final SupabaseClient _supabase;

  AIService({String? apiKey, SupabaseClient? supabase})
      : apiKey = apiKey ?? dotenv.env['Gemini_API_Key'] ?? _fallbackApiKey,
        _supabase = supabase ?? Supabase.instance.client;

  // Basic sentiment analysis for a single entry
  Future<Sentiment> analyzeSentiment(String content) async {
    try {
      // Check if API key is valid before making request
      if (apiKey.isEmpty) {
        Logger.e('AIService', 'Missing Gemini API key');
        return Sentiment.neutral;
      }

      final response = await _makeGeminiRequest(
        prompt: AIPredefinedPrompts.sentimentAnalysisPrompt(content),
      );

      final result = response.toLowerCase().trim();

      if (result.contains('positive')) {
        return Sentiment.positive;
      } else if (result.contains('negative')) {
        return Sentiment.negative;
      } else {
        return Sentiment.neutral;
      }
    } catch (e) {
      Logger.e('AIService', 'Error analyzing sentiment: $e');
      return Sentiment.neutral;
    }
  }

  // Generate a smart summary for a single entry
  Future<String> generateEntrySummary(JournalEntry entry) async {
    try {
      final response = await _makeGeminiRequest(
        prompt: AIPredefinedPrompts.entrySummaryPrompt(entry),
      );

      return response;
    } catch (e) {
      Logger.e('AIService', 'Error generating entry summary: $e');
      return "Unable to generate summary.";
    }
  }

  // Generate weekly summary from multiple entries
  Future<String> generateWeeklySummary(List<JournalEntry> entries) async {
    try {
      final response = await _makeGeminiRequest(
        prompt: AIPredefinedPrompts.weeklySummaryPrompt(entries),
      );

      return response;
    } catch (e) {
      Logger.e('AIService', 'Error generating weekly summary: $e');
      return "Unable to generate weekly summary.";
    }
  }

  // Generate monthly summary from multiple entries
  Future<String> generateMonthlySummary(List<JournalEntry> entries) async {
    try {
      final response = await _makeGeminiRequest(
        prompt: AIPredefinedPrompts.monthlySummaryPrompt(entries),
      );

      return response;
    } catch (e) {
      Logger.e('AIService', 'Error generating monthly summary: $e');
      return "Unable to generate monthly summary.";
    }
  }

  // Generate personalized insights based on journal entries
  Future<String> generatePersonalizedInsights(
      List<JournalEntry> entries) async {
    try {
      final response = await _makeGeminiRequest(
        prompt: AIPredefinedPrompts.personalizedInsightsPrompt(entries),
      );

      return response;
    } catch (e) {
      Logger.e('AIService', 'Error generating personalized insights: $e');
      return "Unable to generate insights at this time.";
    }
  }

  // Generate personalized affirmations based on journal entries
  Future<String> generateAffirmations(List<JournalEntry> entries) async {
    try {
      final response = await _makeGeminiRequest(
        prompt: AIPredefinedPrompts.affirmationsPrompt(entries),
      );

      return response;
    } catch (e) {
      Logger.e('AIService', 'Error generating affirmations: $e');
      return "Unable to generate affirmations at this time.";
    }
  }

  // Generate dynamic journal prompts based on past entries
  Future<String> generateDynamicPrompt(List<JournalEntry> recentEntries) async {
    try {
      final response = await _makeGeminiRequest(
        prompt: AIPredefinedPrompts.dynamicPromptGeneration(recentEntries),
      );

      return response;
    } catch (e) {
      Logger.e('AIService', 'Error generating dynamic prompt: $e');
      return "What's on your mind today?";
    }
  }

  // Private method to make API requests to Gemini - direct call only
  Future<String> _makeGeminiRequest({required String prompt}) async {
    // Check if API key is available
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key not found');
    }

    // Direct API call to Gemini
    final url = '$baseUrl?key=$apiKey';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.2,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text =
            jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        return text ?? '';
      } else {
        throw Exception(
            'API request failed with status: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      Logger.e('AIService', 'Error calling Gemini API: $e');
      rethrow;
    }
  }
}
