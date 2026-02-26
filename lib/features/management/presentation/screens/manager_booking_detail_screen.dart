import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_booking_providers.dart';
import 'package:soko_mtandao/widgets/app_state_view.dart';

class ManagerBookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const ManagerBookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AppStateView.error(
          title: userMessageForError(err),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
        data: (booking) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.customerName ?? 'Unknown guest',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Booking ID: ${booking.id}'),
                    if ((booking.ticketNumber ?? '').isNotEmpty)
                      Text('Ticket: ${booking.ticketNumber}'),
                    const SizedBox(height: 12),
                    Text('Email: ${booking.customerEmail ?? '-'}'),
                    Text('Phone: ${booking.customerPhone ?? '-'}'),
                    const SizedBox(height: 12),
                    Text('Status: ${booking.status ?? '-'}'),
                    Text('Payment: ${booking.paymentStatus ?? '-'}'),
                    Text(
                      'Total: ${formatTzs(booking.totalPrice)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
