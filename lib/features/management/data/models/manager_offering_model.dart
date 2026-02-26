import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';

class ManagerOfferingModel extends ManagerOffering {
  ManagerOfferingModel({
    required String? id,
    required String hotelId,
    required String title,
    required String description,
    required double basePrice,
    required int maxGuests,
    required bool isActive,
  }) : super(
          id: id,
          hotelId: hotelId,
          title: title,
          description: description,
          basePrice: basePrice,
          maxGuests: maxGuests,
          isActive: isActive,
        );

  factory ManagerOfferingModel.fromJson(Map<String, dynamic> json) {
    return ManagerOfferingModel(
      id: json['id'],
      hotelId: json['hotel_id'],
      title: json['title'],
      description: json['description'],
      basePrice: (json['price'] as num?)?.toDouble() ?? 0.0,
      maxGuests: json['max_guests'] ?? 0,
      isActive: json['is_available'] ?? false,
    );
  }

  factory ManagerOfferingModel.fromEntity(ManagerOffering offering) {
    return ManagerOfferingModel(
      id: offering.id,
      hotelId: offering.hotelId,
      title: offering.title,
      description: offering.description,
      basePrice: offering.basePrice,
      maxGuests: offering.maxGuests,
      isActive: offering.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // if (id != null || id!.isNotEmpty) 'id': id,
      'hotel_id': hotelId,
      'title': title,
      'description': description,
      'price': basePrice,
      'max_guests': maxGuests,
      'is_available': isActive,
    };
  }
}
