class BookingItem {
  final String offeringId;
  final String roomId;

  // Optional snapshot fields for nicer UI without extra lookups
  final String? offeringTitle;
  final String? roomNumber;
  final double? pricePerNight;

  BookingItem({
    required this.offeringId,
    required this.roomId,
    this.offeringTitle,
    this.roomNumber,
    this.pricePerNight,
  });

  Map<String, dynamic> toJson() => {
    'offering_id': offeringId,
    'room_id': roomId,
    'offering_title': offeringTitle,
    'room_number': roomNumber,
    'price_per_night': pricePerNight,
  };

  factory BookingItem.fromJson(Map<String, dynamic> json) => BookingItem(
    offeringId: json['offering_id'],
    roomId: json['room_id'],
    offeringTitle: json['offering_title'],
    roomNumber: json['room_number'],
    pricePerNight: (json['price_per_night'] as num?)?.toDouble(),
  );
}
