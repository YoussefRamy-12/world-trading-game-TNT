class CountryListing {
  final String id;
  final String countryId;
  final String sellerPlayerId;
  final int price;
  final String currency;
  final String status;
  final DateTime? expiresAt;

  const CountryListing({required this.id, required this.countryId, required this.sellerPlayerId, required this.price, this.currency = 'USD', this.status = 'open', this.expiresAt});

  factory CountryListing.fromMap(Map<String, dynamic> map) => CountryListing(
        id: map['id'].toString(), countryId: map['country_id'].toString(), sellerPlayerId: map['seller_player_id'].toString(),
        price: _int(map['price']), currency: (map['currency'] ?? 'USD').toString(), status: (map['status'] ?? 'open').toString(),
        expiresAt: map['expires_at'] == null ? null : DateTime.tryParse(map['expires_at'].toString()),
      );

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
}

class Bid {
  final String id;
  final String listingId;
  final String bidderPlayerId;
  final int amount;
  final String currency;
  final String status;

  const Bid({required this.id, required this.listingId, required this.bidderPlayerId, required this.amount, this.currency = 'USD', this.status = 'pending'});

  factory Bid.fromMap(Map<String, dynamic> map) => Bid(
        id: map['id'].toString(), listingId: map['listing_id'].toString(), bidderPlayerId: map['bidder_player_id'].toString(),
        amount: map['amount'] is num ? (map['amount'] as num).toInt() : int.tryParse('${map['amount']}') ?? 0,
        currency: (map['currency'] ?? 'USD').toString(), status: (map['status'] ?? 'pending').toString(),
      );
}
