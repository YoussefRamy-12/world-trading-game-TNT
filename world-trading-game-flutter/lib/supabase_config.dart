import 'package:flutter/foundation.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

void validateSupabaseConfig() {
  if (!hasSupabaseConfig && kReleaseMode) {
    throw StateError('Missing SUPABASE_URL or SUPABASE_ANON_KEY.');
  }
}
