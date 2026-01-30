// lib/presentation/hotel_detail/widgets/booking_cart_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';

class BookingCartModal extends ConsumerWidget {
  const BookingCartModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingCartProvider);
    final notifier = ref.read(bookingCartProvider.notifier);

    if (state.isEmpty) {
      return const Center(child: Text("No items in cart"));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text("Booking Cart",
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              children: state.cart.bookings.map((booking) {
                return ExpansionTile(
                  title: Text(booking.hotel.name),
                  subtitle: Text(
                    "${booking.items.length} rooms · "
                    "${booking.startDate.toIso8601String().substring(0, 10)} to ${booking.endDate.toIso8601String().substring(0, 10)} · "
                    "\$${booking.totalPrice.toStringAsFixed(2)}",
                  ),
                  children: booking.items.map((item) {
                    return ListTile(
                      leading: const Icon(Icons.hotel),
                      title: Text("Room ${item.room.number} - ${item.offering.title}"),
                      subtitle: Text(
                        "\$${item.offering.pricePerNight} / night",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          notifier.removeRoom(
                            bookingId: booking.id,
                            roomId: item.room.id,
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total: \$${state.totalPrice.toStringAsFixed(2)}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ElevatedButton(
                onPressed: () {
                  context.pushNamed("bookingInitiate");
                },
                child: const Text("Continue"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
