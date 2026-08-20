import 'dart:async';

/// Prevents duplicate submissions from rapid clicks/double-clicks.
/// The guard is UI-side protection only; critical game actions remain atomic
/// because the existing Supabase RPCs perform server-side locking/validation.
class ActionGuard {
  final Map<String, Future<dynamic>> _inFlight = {};

  Future<T> run<T>(String key, Future<T> Function() action) {
    final existing = _inFlight[key];
    if (existing != null) return existing as Future<T>;

    final future = action();
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  bool isRunning(String key) => _inFlight.containsKey(key);
}
