import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_providers.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_cart_summary.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_hotel_section.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_user_info.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/proceed_button.dart';

class BookingReviewScreen extends ConsumerWidget {
  final String bookingId;
  const BookingReviewScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingFlowProvider);

    ref.listen<BookingFlowState>(bookingFlowProvider, (prev, next) {
      // noop; could handle error snackbars
    });

    // Load booking if not present or mismatched
    if (flow.booking == null || flow.booking!.id != bookingId) {
      ref.read(bookingFlowProvider.notifier).load(bookingId);
    }

    if (flow.isLoading && flow.booking == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (flow.error != null) {
      return Scaffold(body: Center(child: Text(userMessageForError(flow.error!))));
    }
    final booking = flow.booking!;
    final cart = booking.bookingCart;
    final user = booking.user;
      
    return Scaffold(
      appBar: AppBar(title: const Text('Review Booking')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            BookingUserInfo(user: user),
            BookingCartSummary(cart: cart),
        const SizedBox(height: 16),
        ...cart.bookings.map((booking) => BookingHotelSection(booking: booking)),
        const SizedBox(height: 24),
        ProceedToPaymentButton(bookingId: booking.id),
          ],
        ),
      ),
    );
  }
}

