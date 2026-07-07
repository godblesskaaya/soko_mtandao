import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_booking_providers.dart';
import 'package:soko_mtandao/widgets/app_state_view.dart';

class ManagerBookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const ManagerBookingDetailScreen({super.key, required this.bookingId});

  Future<void> _cancelBooking(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
          'Unpaid bookings are cancelled immediately and pending inventory is released. Paid bookings are sent to refund review instead of being force-cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ref.read(cancelBookingUseCaseProvider).call(bookingId);
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (_) {
        ref.invalidate(bookingDetailProvider(bookingId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancellation request processed.')),
        );
      },
    );
  }

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
        data: (booking) {
          final status = (booking.status ?? '').toLowerCase();
          final paymentStatus = (booking.paymentStatus ?? '').toLowerCase();
          final canCancel =
              status != 'cancelled' && status != 'expired' && status != 'completed';

          return ListView(
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
                      _row('Booking ID', booking.id),
                      if ((booking.ticketNumber ?? '').isNotEmpty)
                        _row('Ticket', booking.ticketNumber!),
                      const Divider(height: 28),
                      _row('Email', booking.customerEmail ?? '-'),
                      _row('Phone', booking.customerPhone ?? '-'),
                      const Divider(height: 28),
                      _row('Booking Status', booking.status ?? '-'),
                      _row('Payment Status', booking.paymentStatus ?? '-'),
                      _row('Payment Type', booking.paymentType ?? '-'),
                      _row('Total', formatTzs(booking.totalPrice)),
                      if (paymentStatus == 'completed' || paymentStatus == 'paid')
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Paid bookings require refund review before inventory or settlement state changes.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed:
                            canCancel ? () => _cancelBooking(context, ref) : null,
                        icon: const Icon(Icons.cancel_schedule_send_outlined),
                        label: const Text('Cancel or Request Refund Review'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
