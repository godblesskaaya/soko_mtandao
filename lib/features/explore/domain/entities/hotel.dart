class Hotel {
  final String id;
  final String name;
  final String? description;
  final HotelLocation location;
  final String? imageUrl;
  final int totalRooms;
  final int availableRooms;

  const Hotel({
    required this.id,
    required this.name,
    required this.location,
    this.description,
    this.imageUrl,
    required this.totalRooms,
    required this.availableRooms,
  });
}

class HotelLocation {
  final double lat;
  final double lng;

  const HotelLocation({required this.lat, required this.lng});
}
