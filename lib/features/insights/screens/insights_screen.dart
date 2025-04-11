import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../journal/providers/journal_provider.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  String _weeklySummary = '';
  String _monthlySummary = '';
  String _insights = '';
  String _affirmations = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final journalNotifier = ref.read(journalProvider.notifier);

      // Get the start of the current week (Sunday)
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday % 7));
      final weekStartDate =
          DateTime(weekStart.year, weekStart.month, weekStart.day);

      // Get the start of the current month
      final monthStartDate = DateTime(now.year, now.month, 1);

      // Load all the AI-generated content
      final weeklySummary =
          await journalNotifier.generateWeeklySummary(weekStartDate);
      final monthlySummary =
          await journalNotifier.generateMonthlySummary(monthStartDate);
      final insights = await journalNotifier.generatePersonalizedInsights();
      final affirmations = await journalNotifier.generateAffirmations();

      setState(() {
        _weeklySummary = weeklySummary;
        _monthlySummary = monthlySummary;
        _insights = insights;
        _affirmations = affirmations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading insights: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Insights'),
            Tab(text: 'Affirmations'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildContentCard(
                  title: 'Weekly Summary',
                  content: _weeklySummary,
                  icon: Icons.calendar_view_week,
                ),
                _buildContentCard(
                  title: 'Monthly Overview',
                  content: _monthlySummary,
                  icon: Icons.calendar_month,
                ),
                _buildContentCard(
                  title: 'Personalized Insights',
                  content: _insights,
                  icon: Icons.lightbulb,
                ),
                _buildContentCard(
                  title: 'Affirmations',
                  content: _affirmations,
                  icon: Icons.favorite,
                ),
              ],
            ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
