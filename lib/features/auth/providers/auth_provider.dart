import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(supabase: Supabase.instance.client);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient supabase;

  AuthNotifier({required this.supabase}) : super(AuthState.initial()) {
    _initialize();

    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        state = AuthState.authenticated(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AuthState.unauthenticated();
      }
    });
  }

  Future<void> _initialize() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      state = AuthState.authenticated(session.user);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      state = const AuthState.loading();
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        state = AuthState.authenticated(response.user!);
      } else {
        state = const AuthState.error('Authentication failed');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow; // Rethrow to show error in UI
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    try {
      state = const AuthState.loading();
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? null : 'auralog://login-callback',
      );

      if (response.user != null) {
        if (response.user!.identities?.isEmpty ?? true) {
          // User already exists
          state = const AuthState.error('Email already registered');
        } else if (response.session != null) {
          // Automatically signed in (default for dev environments)
          state = AuthState.authenticated(response.user!);
        } else {
          // Email confirmation required
          state = const AuthState.unauthenticated(
            message: 'Please check your email to confirm your account',
          );
        }
      } else {
        state = const AuthState.error('Sign up failed');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow; // Rethrow to show error in UI
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      state = const AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}

sealed class AuthState {
  const AuthState();

  factory AuthState.initial() = _Initial;
  const factory AuthState.authenticated(User user) = _Authenticated;
  const factory AuthState.unauthenticated({String? message}) = _Unauthenticated;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.error(String message) = _Error;
}

class _Initial extends AuthState {
  const _Initial();
}

class _Authenticated extends AuthState {
  final User user;
  const _Authenticated(this.user);
}

class _Unauthenticated extends AuthState {
  final String? message;
  const _Unauthenticated({this.message});
}

class _Loading extends AuthState {
  const _Loading();
}

class _Error extends AuthState {
  final String message;
  const _Error(this.message);
}
