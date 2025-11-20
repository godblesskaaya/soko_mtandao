import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';

class ManagerBookingItemModel extends ManagerBookingItem {
  final String id;
  final String? bookingId;
  final String? roomId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? hotelId;
  final String? offeringId;
  final DateTime? createdAt;

  ManagerBookingItemModel({
    required this.id,
    this.bookingId,
    this.roomId,
    this.startDate,
    this.endDate,
    this.hotelId,
    this.offeringId,
    this.createdAt,
  }) : super(
          id: id,
          bookingId: bookingId,
          roomId: roomId,
          startDate: startDate,
          endDate: endDate,
          hotelId: hotelId,
          offeringId: offeringId,
          createdAt: createdAt,
        );

  factory ManagerBookingItemModel.fromJson(Map<String, dynamic> json) {
    return ManagerBookingItemModel(
      id: json['id'],
      bookingId: json['booking_id'],
      roomId: json['room_id'],
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      hotelId: json['hotel_id'],
      offeringId: json['offering_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'room_id': roomId,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'hotel_id': hotelId,
      'offering_id': offeringId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
