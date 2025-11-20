class HotelEntity {
  final String id;
  final String name;
  final String address;
  final String city;
  final String region;
  final String country;
  final double rating;
  final List<String>? images;
  final int availableRooms;
  final double cheapestPrice;

  HotelEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.region,
    required this.country,
    required this.rating,
    required this.images,
    required this.availableRooms,
    required this.cheapestPrice,
  });
}
