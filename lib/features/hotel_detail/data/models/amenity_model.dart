import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';

class AmenityModel extends Amenity {
  AmenityModel({
    required super.id,
    required super.name,
    required super.icon,
  });

  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    return AmenityModel(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
    );
  }

  factory AmenityModel.fromEntity(Amenity amenity) {
    return AmenityModel(
      id: amenity.id,
      name: amenity.name,
      icon: amenity.icon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
      };
}
