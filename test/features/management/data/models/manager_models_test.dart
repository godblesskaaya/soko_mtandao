import 'package:flutter_test/flutter_test.dart';
import 'package:soko_mtandao/features/management/data/models/manager_booking_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_hotel_model.dart';

void main() {
  group('manager models', () {
    test('hotel model preserves total room count from database rows', () {
      final hotel = ManagerHotelModel.fromJson({
        'id': 'hotel-1',
        'name': 'Soko Hotel',
        'rating': 4,
        'region': 'Dar es Salaam',
        'country': 'TZ',
        'city': 'Dar es Salaam',
        'phone_number': '+255700000000',
        'email': 'hello@example.com',
        'lat': 0.0,
        'lng': 0.0,
        'address': 'Market Street',
        'total_rooms': 12,
        'images': const <String>[],
        'description': 'Test hotel',
        'amenities': const <Map<String, dynamic>>[],
      });

      expect(hotel.totalRooms, 12);
    });

    test('booking model serializes database column names', () {
      final json = ManagerBookingModel(
        id: 'booking-1',
        hotelId: 'hotel-1',
        customerName: 'Ada',
        totalPrice: 100,
        paymentStatus: 'pending',
      ).toJson();

      expect(json, containsPair('hotel_id', 'hotel-1'));
      expect(json, containsPair('customer_name', 'Ada'));
      expect(json, containsPair('total_price', 100));
      expect(json, containsPair('payment_status', 'pending'));
      expect(json.containsKey('hotelId'), isFalse);
      expect(json.containsKey('totalPrice'), isFalse);
    });
  });
}
