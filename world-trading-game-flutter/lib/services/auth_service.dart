import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient client;
  AuthService({SupabaseClient? client}) : client = client ?? Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await client.auth.signUp(email: email.trim(), password: password);
  }

  Future<void> signOut() => client.auth.signOut();
}
