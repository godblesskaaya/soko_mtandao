import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/router/route_names.dart';

class ProceedToPaymentButton extends StatelessWidget {
  final String bookingId;

  const ProceedToPaymentButton({super.key, required this.bookingId});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        context.pushNamed('payment', pathParameters: {'id': bookingId}); // or include cart ID if needed
      },
      child: const Text('Proceed to Payment'),
    );
  }
}
