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
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ref
          .read(bookingFlowProvider.notifier)
          .load(widget.bookingId, saveToHistory: true);
    });

    // WidgetsBinding.instance.addPostFrameCallback((_) async{
    //   final notifier = ref.read(bookingFlowProvider.notifier);
    //   await notifier.load(widget.bookingId);

    //   final booking = ref.read(bookingFlowProvider).booking;
    //   if (booking != null) {
    //     await ref
    //         .read(localBookingStorageProvider)
    //         .saveBooking(BookingModel.fromEntity(booking));
    //     ref.invalidate(localBookingHistoryProvider);
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmed')),
      body: Builder(
        builder: (context){
          if (flow.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (flow.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Something went wrong: ${flow.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(bookingFlowProvider.notifier).load(widget.bookingId);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (flow.booking == null) {
            return const Center(child: Text('Booking details not found.'));
          }
          return Padding(
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
                    context.go(RouteNames.guestHome);
                  },
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
