import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';

class BookingCartModal extends ConsumerWidget {
  const BookingCartModal({super.key});

  String _fmt(DateTime date) => formatYmd(date);

  int _roomNights(List<BookingInput> bookings) {
    return bookings.fold<int>(
      0,
      (sum, booking) =>
          sum +
          booking.items.length *
              stayNightsInclusive(booking.startDate, booking.endDate),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingCartProvider);
    final notifier = ref.read(bookingCartProvider.notifier);

    if (state.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No items in cart')),
      );
    }

    final bookings = state.cart.bookings;
    final bookingsByHotel = <String, List<BookingInput>>{};
    for (final booking in bookings) {
      final bucket =
          bookingsByHotel.putIfAbsent(booking.hotel.id, () => <BookingInput>[]);
      bucket.add(booking);
    }
    final hotelGroups = bookingsByHotel.entries.toList()
      ..sort((a, b) =>
          a.value.first.hotel.name.compareTo(b.value.first.hotel.name));

    for (final entry in hotelGroups) {
      entry.value.sort((a, b) => a.startDate.compareTo(b.startDate));
    }

    final hotelCount = hotelGroups.length;
    final roomCount = state.totalItems;
    final roomNights = _roomNights(bookings);

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Booking Cart',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    notifier.clearCart();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Hotels',
                        value: hotelCount.toString(),
                        icon: Icons.apartment,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'Rooms',
                        value: roomCount.toString(),
                        icon: Icons.meeting_room,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'Room-nights',
                        value: roomNights.toString(),
                        icon: Icons.nights_stay,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: hotelGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final group = hotelGroups[index];
                final hotelBookings = group.value;
                final hotel = hotelBookings.first.hotel;
                final hotelRooms = hotelBookings.fold<int>(
                    0, (sum, booking) => sum + booking.items.length);
                final hotelStays = hotelBookings.length;
                final hotelTotal = hotelBookings.fold<double>(
                    0, (sum, booking) => sum + booking.totalPrice);
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotel.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text('$hotelStays stay(s) | $hotelRooms room(s)'),
                        const SizedBox(height: 8),
                        ...hotelBookings.map(
                          (booking) {
                            final nights = stayNightsInclusive(
                                booking.startDate, booking.endDate);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.event, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${_fmt(booking.startDate)} -> ${_fmt(booking.endDate)}',
                                        ),
                                      ),
                                      Text('$nights nights'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...booking.items.map(
                                    (item) => _CartRoomRow(
                                      item: item,
                                      nights: nights,
                                      onRemove: () {
                                        notifier.removeRoom(
                                          bookingId: booking.id,
                                          roomId: item.room.id,
                                        );
                                      },
                                    ),
                                  ),
                                  const Divider(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Stay subtotal: ${formatTzs(booking.totalPrice)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Hotel subtotal: ${formatTzs(hotelTotal)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Grand total',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      formatTzs(state.totalPrice),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Review your selections before entering guest details.'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.pushNamed('bookingInitiate');
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue to Guest Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _CartRoomRow extends StatelessWidget {
  final BookingItemInput item;
  final int nights;
  final VoidCallback onRemove;

  const _CartRoomRow({
    required this.item,
    required this.nights,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = item.offering.pricePerNight * nights;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.hotel_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.offering.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Room ${item.room.number}  |  ${formatTzs(item.offering.pricePerNight)} x $nights nights',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  'Subtotal: ${formatTzs(total)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove room',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
