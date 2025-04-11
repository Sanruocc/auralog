import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isLoggedIn = false;

  RouterNotifier(this._ref) {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    try {
      _ref.listen(authProvider, (previous, next) {
        try {
          final isAuthenticated =
              next.runtimeType.toString() == '_Authenticated';
          _isLoggedIn = isAuthenticated;
          notifyListeners();
        } catch (e) {
          debugPrint('Error processing auth state change: $e');
          // If there's an error processing the auth state, default to not logged in
          _isLoggedIn = false;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error setting up auth listener: $e');
      // If there's an error setting up the listener, default to not logged in
      _isLoggedIn = false;
    }
  }

  bool get isLoggedIn => _isLoggedIn;
}
