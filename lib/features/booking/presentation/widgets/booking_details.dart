import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_expiry_countdown.dart';

class BookingDetailsWidget extends StatelessWidget {
  final Booking booking;
  final bool showPriceSummary;

  const BookingDetailsWidget({
    super.key,
    required this.booking,
    this.showPriceSummary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer Info",
                style: Theme.of(context).textTheme.titleMedium),
            Text("Name: ${booking.user.name}"),
            Text("Email: ${booking.user.email}"),
            Text("Phone: ${booking.user.phone}"),
            const SizedBox(height: 12),
            Text("Status: ${booking.status.name}"),
            Text("Payment Status: ${booking.paymentStatus.name}"),
            if (booking.status == BookingStatusEnum.pending &&
                booking.paymentStatus == PaymentStatusEnum.pending &&
                booking.expiresAt != null) ...[
              const SizedBox(height: 8),
              BookingExpiryCountdown(expiresAt: booking.expiresAt!),
            ],
            const SizedBox(height: 12),

            Text("Booking Details",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            Text("Booking ID: ${booking.id}"),
            // iterate through bookings in the cart and display all bookings and their details
            for (var b in booking.bookingCart.bookings) ...[
              Text("Hotel: ${b.hotel.name}"),
              // display start and end date in yyyy-mm-dd format
              Text(
                  "Check-in: ${b.startDate.toIso8601String().substring(0, 10)}"),
              Text(
                  "Check-out: ${b.endDate.toIso8601String().substring(0, 10)}"),

              Text("Rooms Selected:",
                  style: Theme.of(context).textTheme.titleMedium),
              ...b.items.map((item) => ListTile(
                    title: Text(item.offering.title),
                    subtitle: Text(
                        "Room: ${item.room.number} | Guests: ${item.offering.maxGuests}"),
                    trailing: Text(
                        "${formatTzs(item.offering.pricePerNight)} / night"),
                  )),
            ],
            const Divider(),

            if (showPriceSummary) ...[
              const Divider(),
              Text("Total Price: ${formatTzs(booking.totalPrice)}",
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ],
        ),
      ),
    );
  }
}
