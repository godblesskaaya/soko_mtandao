// lib/presentation/hotel_detail/widgets/booking_cart_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';

class BookingCartModal extends ConsumerWidget {
  const BookingCartModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(bookingCartProvider);
    final notifier = ref.read(bookingCartProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Booking Cart", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (cart == null || cart.isEmpty)
            Text("No items in cart")
          else
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.bookings.length,
                itemBuilder: (_, index) {
                  final booking = cart.bookings[index];
                  final nights = booking.endDate.difference(booking.startDate).inDays;

                  return ExpansionTile(
                    title: Text(booking.hotel.name),
                    subtitle: Text("${booking.totalItems} rooms | ${nights} nights | \$${booking.totalPrice.toStringAsFixed(2)}",
                    ),
                    children: [
                      ...booking.items.map((item) {
                        return ListTile(
                          leading: const Icon(Icons.hotel),
                          title: Text("Room ${item.room.number} - ${nights} nights"),
                          subtitle: Text("\$${item.offering.pricePerNight} / night"),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => notifier.removeItemFromBooking(booking, item),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                  // return ListTile(
                  //   title: Text("${booking.items.first.room.number} - ${nights} nights"),
                  //   subtitle: Text("\$${booking.offering.pricePerNight} / night"),
                  //   trailing: IconButton(
                  //     icon: Icon(Icons.delete, color: Colors.red),
                  //     onPressed: () => notifier.removeFromCart(booking),
                  //   ),
                  // );
                },
              ),
            ),
            const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total: \$${cart?.totalPrice.toStringAsFixed(2)}",
                  style: Theme.of(context).textTheme.titleMedium),
              ElevatedButton(
                onPressed: () {
                  // Navigate to booking screen
                  context.pushNamed("bookingInitiate");
                },
                child: Text("Continue"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
