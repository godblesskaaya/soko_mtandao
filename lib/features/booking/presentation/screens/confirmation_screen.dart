import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_providers.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_details.dart';

class BookingConfirmationScreen extends ConsumerWidget {
  final String bookingId;
  const BookingConfirmationScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingFlowProvider);
    if (flow.booking == null || flow.booking!.id != bookingId) {
      ref.read(bookingFlowProvider.notifier).load(bookingId);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmed')),
      body: flow.booking == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text('Thank you, ${flow.booking!.user.name}.',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),

                  BookingDetailsWidget(booking: flow.booking!, showPriceSummary: true),

                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
    );
  }
}
