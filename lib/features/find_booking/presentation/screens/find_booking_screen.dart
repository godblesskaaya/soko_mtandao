import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_details.dart';
import '../riverpod/find_booking_provider.dart';

class FindBookingScreen extends ConsumerStatefulWidget {
  const FindBookingScreen({super.key});

  @override
  ConsumerState<FindBookingScreen> createState() => _FindBookingScreenState();
}

class _FindBookingScreenState extends ConsumerState<FindBookingScreen> {
  final _controller = TextEditingController();
  String? bookingId;

  @override
  Widget build(BuildContext context) {
    final asyncResult = bookingId != null
        ? ref.watch(findBookingProvider(bookingId!))
        : null;

    return Column(children: [
      AppBar(title: const Text("Find Booking")),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Enter Booking ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  bookingId = _controller.text.trim();
                });
              },
              child: const Text("Search"),
            ),
            const SizedBox(height: 24),
            if (asyncResult != null)
              asyncResult.when(
                data: (result) {
                  if (!result.found) {
                    return const Text("❌ Booking not found");
                  }
                  return BookingDetailsWidget(booking: result.booking!);
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text("Error: $e"),
              ),
          ],
        ),
      ),
    ],
    );
  }
}
