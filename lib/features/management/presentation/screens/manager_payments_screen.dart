// lib/features/management/presentation/pages/hotel_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_payment_provider.dart'; 

class ManagerPaymentsScreen extends ConsumerWidget {
  final String hotelId;

  // Constructor requires the hotelId to query the specific payments
  const ManagerPaymentsScreen({
    required this.hotelId, 
    super.key
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the FutureProvider.family, passing the required hotelId.
    final paymentsAsyncValue = ref.watch(managerPaymentsProvider(hotelId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Payments',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold
            ),
          ),
        ),
        const Divider(height: 1),
        
        // 2. Handle the AsyncValue states using the .when() method
        Expanded(
          child: paymentsAsyncValue.when(
            // --- A. Loading State ---
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching hotel payments...')
                ],
              ),
            ),
            
            // --- B. Error State ---
            error: (error, stackTrace) {
              // Extract the error message, preferring the custom Failure message
              final errorMessage = (error is Failure) 
                  ? error.message 
                  : 'An unknown error occurred.';
              
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to Load Payments: $errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      // Button to retry fetching the data
                      TextButton(
                        onPressed: () {
                          // This line forces the provider to re-fetch the data
                          ref.invalidate(managerPaymentsProvider(hotelId));
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
            
            // --- C. Data State ---
            data: (payments) {
              if (payments.isEmpty) {
                return const Center(child: Text('No payments recorded for this hotel.'));
              }
              
              return ListView.separated(
                itemCount: payments.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ManagerPayment payment = payments[index];
                  return PaymentListTile(payment: payment);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Helper Widget for cleaner UI ---
class PaymentListTile extends StatelessWidget {
  final ManagerPayment payment;

  const PaymentListTile({required this.payment, super.key});

  @override
  Widget build(BuildContext context) {
    // Determine color based on payment status
    Color statusColor;
    switch (payment.paymentStatus.toLowerCase()) {
      case 'successful':
      case 'paid':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'failed':
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blueGrey;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.1),
        child: Icon(Icons.payment, color: statusColor),
      ),
      title: Text(
        '${payment.customerName ?? 'Unknown Customer'}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Booking: #${payment.ticketNumber ?? payment.bookingId}\nType: ${payment.paymentType ?? 'N/A'}',
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            payment.paymentStatus,
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
        ],
      ),
      onTap: () {
        // Implement navigation or a bottom sheet to show full payment details
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing payment ID: ${payment.paymentId}')),
        );
      },
    );
  }
}