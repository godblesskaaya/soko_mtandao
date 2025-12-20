import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/data/services/local_booking_storage_service.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_providers.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_details.dart';
import 'package:soko_mtandao/router/route_names.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingConfirmationScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends ConsumerState<BookingConfirmationScreen> {
  @override
  void initstate() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(bookingFlowProvider);
      ref.read(bookingFlowProvider.notifier).load(widget.bookingId);
      _loadAndSave();
    });
  }

  Future<void> _loadAndSave() async {
    final flowNotifier = ref.read(bookingFlowProvider.notifier);
    await flowNotifier.load(widget.bookingId);

    final flowState = ref.read(bookingFlowProvider);
    if (flowState.booking != null) {
      await ref.read(localBookingStorageProvider).saveBooking(BookingModel.fromEntity(flowState.booking!));
      ref.invalidate(localBookingHistoryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    if (flow.booking == null || flow.booking!.id != widget.bookingId) {
      ref.read(bookingFlowProvider.notifier).load(widget.bookingId);
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
                      ref.invalidate(bookingFlowProvider);
                      context.go(RouteNames.guestHome);
                    },
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
    );
  }
}
