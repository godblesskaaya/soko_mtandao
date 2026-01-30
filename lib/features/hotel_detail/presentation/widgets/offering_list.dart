import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/offering.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';
import 'package:uuid/uuid.dart';

class OfferingsList extends ConsumerWidget {
  final List<Offering> offerings;
  final String hotelId;
  final DateTime startDate;
  final DateTime endDate;
  const OfferingsList({required this.offerings, required this.hotelId, required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (offerings.isEmpty) {
      return const Text("No offerings for selected dates.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: offerings.map((off) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(off.title),
            subtitle: Text("From \$${off.pricePerNight}/night"),
            trailing: ElevatedButton(
              onPressed: () {
                _showRoomModal(context, ref, off);
              },
              child: const Text("Select Room"),
            ),
          ),
        );
      }).toList(),
    );
  }

void _showRoomModal(BuildContext context, WidgetRef ref, Offering offering) {
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return Consumer(
        builder: (context, ref, _) {
          final roomsAsync = ref.watch(
            roomAvailabilityProvider((
              hotelId: hotelId,
              offeringId: offering.id,
              startdate: startDate,
              enddate: endDate,
            )),
          );

          return roomsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text("Error: $err")),
            // check if rooms list is empty and show message
            data: (rooms) {
              if (rooms.isEmpty) {
                return const Center(child: Text("No rooms available for this offering."));
              }
              return ListView(
                children: rooms.map((room) {
                  return ListTile(
                    title: Text("Room ${room.number}"),
                    trailing: ElevatedButton(
                      onPressed: () {
                        // fetch hotel, room, offering
                        final hotelAsync = ref.read(hotelDetailProvider(hotelId));
                        final hotel = hotelAsync.value!;
                        final booking = BookingInput(
                          id: const Uuid().v4(),
                          hotel: hotel,
                          startDate: startDate,
                          endDate: endDate,
                          items: const [],
                        );

                        final item = BookingItemInput(
                          room: room,
                          offering: offering,
                        );

                        // add to booking cart and case of error show snackbar
                        try {
                          ref.read(bookingCartProvider.notifier).addRoom(
                            booking: booking,
                            item: item,
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("$e")),
                          );
                        }
                        Navigator.pop(context);
                      },
                      child: const Text("Add to cart"),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      );
    },
  );
}

}
