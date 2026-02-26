class ManagerAmenity {
  final String amenityId;
  final String name;
  final String category;
  final String? shortDescription;
  final String availabilityStatus;
  final String? iconUrl;
  final bool isActive;

  ManagerAmenity({
    required this.amenityId,
    required this.name,
    required this.category,
    this.shortDescription,
    required this.availabilityStatus,
    this.iconUrl,
    this.isActive = true,
  });
}
