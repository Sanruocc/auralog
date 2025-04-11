import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  // Fallback values - replace with your actual Supabase URL and anon key in production
  static const String _fallbackUrl = 'https://zwxpyxhlrnegnefupuxv.supabase.co';
  static const String _fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHB5eGhscm5lZ25lZnVwdXh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQyNzEwMzQsImV4cCI6MjA1OTg0NzAzNH0.9xPhf0LaJXat5LQDj6_odh5ivLSH6XzyxOxakPNbIa0';

  static String get url => dotenv.env['SUPABASE_URL'] ?? _fallbackUrl;
  static String get anonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _fallbackAnonKey;
}
