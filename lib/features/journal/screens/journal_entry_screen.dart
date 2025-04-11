import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';

class JournalEntryScreen extends ConsumerStatefulWidget {
  final JournalEntry? entry;
  const JournalEntryScreen({super.key, this.entry});

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  final _contentController = TextEditingController();
  Mood _selectedMood = Mood.okay;
  bool _isLoading = false;
  bool _isSentimentAnalysisVisible = false;
  Sentiment? _sentiment;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _contentController.text = widget.entry!.content;
      _selectedMood = widget.entry!.mood;
      _sentiment = widget.entry!.sentiment;
      if (_sentiment != null) {
        _isSentimentAnalysisVisible = true;
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(journalProvider.notifier).addEntry(
            content: _contentController.text.trim(),
            mood: _selectedMood,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _analyzeSentiment() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Access the AIService through the journal provider
      final aiService = ref.read(journalProvider.notifier).aiService;

      // Analyze sentiment
      final sentiment =
          await aiService.analyzeSentiment(_contentController.text);

      setState(() {
        _sentiment = sentiment;
        _isSentimentAnalysisVisible = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing sentiment: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New Entry' : 'View Entry'),
        actions: [
          if (!_isLoading && widget.entry == null)
            IconButton(
              icon: const Icon(Icons.psychology),
              tooltip: 'Analyze Sentiment',
              onPressed: _analyzeSentiment,
            ),
          if (!_isLoading && widget.entry == null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveEntry,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: Mood.values.map((mood) {
                    return InkWell(
                      onTap: widget.entry == null
                          ? () => setState(() => _selectedMood = mood)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedMood == mood
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              mood.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 4),
                            Text(mood.label),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSentimentAnalysisVisible && _sentiment != null) ...[
              Card(
                color: () {
                  switch (_sentiment) {
                    case Sentiment.positive:
                      return Colors.green.shade50;
                    case Sentiment.negative:
                      return Colors.red.shade50;
                    case Sentiment.neutral:
                      return Colors.blue.shade50;
                    default:
                      return null;
                  }
                }(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'AI Detected Sentiment',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _sentiment!.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _sentiment!.name.toUpperCase(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 10,
              readOnly: widget.entry != null,
              decoration: const InputDecoration(
                hintText: 'Write your thoughts...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (widget.entry?.summary != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Summary',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(widget.entry!.summary!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
