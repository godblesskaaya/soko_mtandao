class ManagerOffering {
  final String? id;
  final String hotelId;
  final String title;
  final String description;
  final double basePrice;
  final int maxGuests;
  final bool isActive;

  ManagerOffering({
    required this.id,
    required this.hotelId,
    required this.title,
    required this.description,
    required this.basePrice,
    required this.maxGuests,
    this.isActive = true,
  });
}
