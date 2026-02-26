import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failure_mapper.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/booking/data/services/payment_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CheckoutState { idle, loading, error }

class PaymentFlowState {
  final CheckoutState state;
  final String? checkoutUrl;
  final Failure? error;
  PaymentFlowState({
    required this.state,
    this.checkoutUrl,
    this.error,
  });

  String? get errorMessage => error?.message;
}

class PaymentFlowNotifier extends StateNotifier<PaymentFlowState> {
  final PaymentService service;
  PaymentFlowNotifier(this.service)
      : super(PaymentFlowState(state: CheckoutState.idle));

  Future<void> startCheckout(String bookingId) async {
    state = PaymentFlowState(state: CheckoutState.loading);
    try {
      final url = await service.createHostedCheckout(bookingId: bookingId);
      state = PaymentFlowState(state: CheckoutState.idle, checkoutUrl: url);
    } catch (e) {
      state = PaymentFlowState(
        state: CheckoutState.error,
        error: failureFromError(e),
      );
    }
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final client = Supabase.instance.client;
  return PaymentService(client: client);
});

final paymentFlowProvider =
    StateNotifierProvider<PaymentFlowNotifier, PaymentFlowState>((ref) {
  final svc = ref.watch(paymentServiceProvider);
  return PaymentFlowNotifier(svc);
});
