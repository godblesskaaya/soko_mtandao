import 'dart:async';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/data/models/user_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking_item.dart';
import 'package:soko_mtandao/features/booking/data/datasources/booking_datasource.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_cart_model.dart';

class BookingMockDataSource implements BookingDataSource {
  final MockState mockState;
  BookingMockDataSource({this.mockState = MockState.success});

  @override
  Future<BookingModel> initiateBooking({
    required UserModel user,
    required BookingCartModel cart,
    required String sessionId,
  }) async {
    if (mockState == MockState.loading) {
      await Future.delayed(const Duration(seconds: 2));
    }
    if (mockState == MockState.error) {
      throw Exception('Mock: failed to initiate booking');
    }

    // Just use first booking in cart for demo (one hotel per checkout)
    final b = cart.bookings.first;
    final items = b.items
        .map((i) => BookingItem(
              offeringId: i.offering.id,
              roomId: i.room.id,
              offeringTitle: i.offering.title,
              roomNumber: i.room.number,
              pricePerNight: i.offering.pricePerNight,
            ))
        .toList();

    final model = BookingModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      user: user,
      status: BookingStatusEnum.pending,
      paymentStatus: PaymentStatusEnum.initiated,
      ticketNumber: null,
      totalPrice: b.totalPrice,
      bookingCart: cart,
    );
    return model;
  }

  @override
  Future<BookingModel> getBooking(String bookingId) async {
    // Return a stable demo object
    return BookingModel.fromJson(
      {
        "id": bookingId,
        "status": "confirmed",
        "payment_status": "completed",
        "ticket_number": "ABC123",
        "total_price": 999.99,
        "user": {
          "name": "Jane Doe",
          "email": "jane@example.com",
          "phone": "1234567890"
        },
        "booking_cart": {
          "totalItems": 3,
          "totalPrice": 999.99,
          "bookings": [
            {
              "startDate": "2025-09-01T00:00:00Z",
              "endDate": "2025-09-05T00:00:00Z",
              "hotel": {
                "id": "h2",
                "name": "remada resort",
                "description": "Another cozy place with mock data.",
                "address": "456 Mock Avenue",
                "rating": 4.0,
                "images": [
                  "https://picsum.photos/800/400",
                  "https://picsum.photos/801/400"
                ],
                "amenities": [
                  {"id": "a1", "name": "Free WiFi", "icon": "wifi"},
                  {"id": "a2", "name": "Swimming Pool", "icon": "pool"}
                ]
              },
              "items": [
                {
                  "offering": {
                    "id": "off1",
                  },
                  "room": {
                    "id": "room1",
                    "number": "101",
                  }
                }
              ]
            }
          ]
        }
      },
    );
  }

  @override
  Future<BookingModel> getBookingStatus(String bookingId) async {
    // Simulate payment progress → completed after some cycles
    await Future.delayed(const Duration(milliseconds: 600));
    // flip to completed sometimes
    final completed = DateTime.now().second % 6 == 0;
    BookingStatusEnum status =
        completed ? BookingStatusEnum.confirmed : BookingStatusEnum.pending;
    PaymentStatusEnum paymentStatus =
        completed ? PaymentStatusEnum.completed : PaymentStatusEnum.pending;

    return BookingModel.fromJson({
      "id": bookingId,
      "status": status.name,
      "payment_status": paymentStatus.name,
      "ticket_number": "ABC123",
      "total_price": 999.99,
      "user": {
        "name": "Jane Doe",
        "email": "jane@example.com",
        "phone": "1234567890"
      },
      "booking_cart": {
        "totalItems": 3,
        "totalPrice": 999.99,
        "bookings": [
          {
            "startDate": "2025-09-01",
            "endDate": "2025-09-05",
            "hotel": {
              "id": "hotel1",
              "name": "Sunset Hotel",
            },
            "items": [
              {
                "offering": {
                  "id": "off1",
                  "title": "Deluxe Room",
                  "price_per_night": 199.99,
                },
                "room": {
                  "id": "room1",
                  "number": "101",
                }
              }
            ]
          }
        ]
      }
    });
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<BookingSearchResult> findBookingById(String bookingId) async {
    final booking = await getBooking(bookingId);
    if (booking != null) {
      return BookingSearchResult(booking: booking, found: true);
    } else {
      return BookingSearchResult(booking: null, found: false);
    }
  }

  @override
  Stream<BookingModel> monitorBookingPayment(String bookingId) {
    // TODO: implement monitorBookingPayment
    throw UnimplementedError();
  }
}
