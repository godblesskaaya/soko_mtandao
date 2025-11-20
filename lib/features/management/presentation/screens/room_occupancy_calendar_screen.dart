// features/manager/presentation/screens/room_occupancy_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_booking_providers.dart';
import 'package:table_calendar/table_calendar.dart';

class RoomOccupancyCalendarScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomOccupancyCalendarScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomOccupancyCalendarScreen> createState() =>
      _RoomOccupancyCalendarScreenState();
}

class _RoomOccupancyCalendarScreenState
    extends ConsumerState<RoomOccupancyCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(roomBookingsProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(title: const Text("Room Occupancy")),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (bookings) {
          final bookedDays = _mapBookingsToDays(bookings);

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) {
                    final isBooked = bookedDays.contains(day);
                    return Container(
                      decoration: BoxDecoration(
                        color: isBooked ? Colors.red[300] : Colors.green[200],
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text("${day.day}"),
                    );
                  },
                ),
              ),
              if (_selectedDay != null) ...[
                const SizedBox(height: 16),
                Text("Bookings for ${_selectedDay!.toLocal()}"),
                Expanded(
                  child: ListView(
                    children: bookings
                        .where((b) =>
                            b.startDate != null &&
                            b.startDate!.isBefore(_selectedDay!.add(const Duration(days: 1))) &&
                            b.endDate != null &&
                            b.endDate!.isAfter(_selectedDay!))
                        .map((b) => Consumer(
                              builder: (context, ref, _) {
                                final bookingDetailAsync = ref.watch(bookingDetailProvider(b.bookingId ?? ''));

                                return bookingDetailAsync.when(
                                  loading: () => const ListTile(
                                    title: Text("Loading booking..."),
                                    subtitle: LinearProgressIndicator(),
                                  ),
                                  error: (err, stack) => ListTile(
                                    title: const Text("Failed to load booking"),
                                    subtitle: Text(err.toString()),
                                  ),
                                  data: (booking) {
                                    final cart = booking.ticketNumber;
                                    final hotel = booking.hotelId;
                                    final item = booking.totalPrice;
                                    final room = b.roomId;
                                    final offering = b.offeringId;
                                    final userData = {
                                      'name': booking.customerName,
                                      'email': booking.customerEmail,
                                      'phone': booking.customerPhone,
                                    };

                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        // title: Text(hotel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            Text("Room: ${room} (${offering})"),
                                            // Text("Guests: Max ${offering?.maxGuests}"),
                                            // Text("Price/Night: ${b.pricePerNight.toStringAsFixed(0)}"),
                                            const SizedBox(height: 8),
                                            Text("Booked by: ${userData['name']}"),
                                            Text("Email: ${userData['email']}"),
                                            Text("Phone: ${userData['phone']}"),
                                            const SizedBox(height: 8),
                                            Text("Check-in: ${b.startDate?.toLocal().toIso8601String().substring(0,10)}"),
                                            Text("Check-out: ${b.endDate?.toLocal().toIso8601String().substring(0,10)}"),
                                            const SizedBox(height: 8),
                                            Text("Status: ${booking.status}"),
                                            Text("Total: ${booking.totalPrice?.toStringAsFixed(0)}"),
                                          ],
                                        ),
                                        // leading: hotel.images.isNotEmpty
                                        //     ? Image.network(
                                        //         hotel.images.first,
                                        //         width: 60,
                                        //         height: 60,
                                        //         fit: BoxFit.cover,
                                        //       )
                                        //     : const Icon(Icons.hotel),
                                      ),
                                    );
                                  },
                                );
                              },
                            ))
                        .toList(),
                  ),
                ),
              ]
            ],
          );
        },
      ),
    );
  }

  Set<DateTime> _mapBookingsToDays(List<ManagerBookingItem> bookings) {
    final Set<DateTime> days = {};
    for (var b in bookings) {
      DateTime day = b.startDate ?? DateTime.now();
      while (day.isBefore(b.endDate!.add(const Duration(days: 1)))) {
        days.add(DateTime.utc(day.year, day.month, day.day));
        day = day.add(const Duration(days: 1));
      }
    }
    return days;
  }
}
