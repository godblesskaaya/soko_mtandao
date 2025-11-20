import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';

class ManagerAmenityModel extends ManagerAmenity {
  final String amenityId;
  final String name;
  final String category;
  final String? shortDescription;
  final String availabilityStatus;
  final String? iconUrl;
  final bool isActive;

  ManagerAmenityModel({
    required this.amenityId,
    required this.name,
    required this.category,
    this.shortDescription,
    required this.availabilityStatus,
    this.iconUrl,
    this.isActive = true,
  }) : super(
          amenityId: amenityId,
          name: name,
          category: category,
          shortDescription: shortDescription,
          availabilityStatus: availabilityStatus,
          iconUrl: iconUrl,
          isActive: isActive,
      );

  factory ManagerAmenityModel.fromJson(Map<String, dynamic> json) {
    return ManagerAmenityModel(
      amenityId: json['amenity_id'], 
      name: json['name'],
      category: json['category'],
      shortDescription: json['short_description'],
      availabilityStatus: json['availability_status'],
      iconUrl: json['icon_url'],
      isActive: json['is_active'] ?? true,
    );
  }

}