import 'package:flutter/foundation.dart';
import '../models/country.dart';
import 'game_repository.dart';

class GameState extends ChangeNotifier {
  final GameRepository repository;
  GameState({GameRepository? repository}) : repository = repository ?? GameRepository();

  List<Country> countries = const [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      countries = await repository.fetchPublicCountriesWithValues();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
