import 'action_guard.dart';
import 'game_repository.dart';

class GameActions {
  final GameRepository repository;
  final ActionGuard guard;

  GameActions({GameRepository? repository, ActionGuard? guard})
      : repository = repository ?? GameRepository(),
        guard = guard ?? ActionGuard();

  Future<String> addBuilding({required String countryId, required int buildingTypeId}) =>
      guard.run(
        'add-building:$countryId:$buildingTypeId',
        () => repository.purchaseBuildings(
          countryId: countryId,
          buildingTypeId: buildingTypeId,
          quantity: 1,
        ),
      );

  Future<String> buyCountry(String listingId) =>
      guard.run('buy:$listingId', () => repository.buyCountry(listingId));

  Future<String> placeBid({required String listingId, required int amount, String currency = 'USD'}) =>
      guard.run(
        'bid:$listingId:$amount:$currency',
        () => repository.placeBid(listingId: listingId, amount: amount, currency: currency),
      );

  Future<String> sellCountry({required String countryId, required int price, String currency = 'USD'}) =>
      guard.run(
        'sell:$countryId',
        () => repository.sellCountry(countryId: countryId, price: price, currency: currency),
      );
}
