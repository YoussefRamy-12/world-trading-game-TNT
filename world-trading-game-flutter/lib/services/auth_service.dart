import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient client;
  AuthService({SupabaseClient? client}) : client = client ?? Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
    );
  }

  Future<void> signOut() => client.auth.signOut();
}
