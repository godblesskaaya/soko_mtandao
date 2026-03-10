import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';

enum NativePaymentMethod { mno, bank }

class NativeCheckoutResult {
  final bool success;
  final String? transactionId;
  final String? message;

  NativeCheckoutResult({
    required this.success,
    this.transactionId,
    this.message,
  });
}

class PaymentService {
  final SupabaseClient client;

  PaymentService({required this.client});

  /// Calls the Supabase Edge Function to initiate AzamPay hosted checkout
  Future<String> createHostedCheckout({
    required String bookingId,
    String? ticketNumber,
    String? successRedirect,
    String? failRedirect,
  }) async {
    final payload = {
      'booking_id': bookingId,
      'redirectSuccessURL': successRedirect ??
          '${AppConfig.appBaseUrl}/payment-success/$bookingId',
      'redirectFailURL':
          failRedirect ?? '${AppConfig.appBaseUrl}/payment-failed',
      if ((ticketNumber ?? '').trim().isNotEmpty)
        'ticket_number': ticketNumber!.trim(),
    };

    final response = await client.functions.invoke(
      'create_checkout',
      body: payload,
    );

    if (response.status == 200 &&
        response.data is Map<String, dynamic> &&
        response.data['checkoutUrl'] != null) {
      return response.data['checkoutUrl'];
    } else {
      throw Exception(
          'Failed to create AzamPay checkout: ${response.data ?? response.status}');
    }
  }

  Future<NativeCheckoutResult> createNativeCheckout({
    required String bookingId,
    String? ticketNumber,
    required NativePaymentMethod method,
    required double amount,
    String currency = 'TZS',
    String? mnoAccountNumber,
    String? mnoProvider,
    String? bankProvider,
    String? bankMerchantAccountNumber,
    String? bankMerchantMobileNumber,
    String? bankOtp,
    String? bankMerchantName,
  }) async {
    final body = <String, dynamic>{
      'booking_id': bookingId,
      'method': method.name,
      'amount': amount,
      'currency': currency,
      if ((ticketNumber ?? '').trim().isNotEmpty)
        'ticket_number': ticketNumber!.trim(),
    };

    if (method == NativePaymentMethod.mno) {
      body['account_number'] = mnoAccountNumber;
      body['provider'] = mnoProvider;
    } else {
      body['provider'] = bankProvider;
      body['merchant_account_number'] = bankMerchantAccountNumber;
      body['merchant_mobile_number'] = bankMerchantMobileNumber;
      body['otp'] = bankOtp;
      if (bankMerchantName != null && bankMerchantName.trim().isNotEmpty) {
        body['merchant_name'] = bankMerchantName.trim();
      }
    }

    final response = await client.functions.invoke(
      'create_checkout_native',
      body: body,
    );

    if (response.status == 200 && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      return NativeCheckoutResult(
        success: data['success'] == true,
        transactionId: data['transactionId']?.toString(),
        message: data['message']?.toString(),
      );
    }

    throw Exception(
      'Failed to initiate native checkout: ${response.data ?? response.status}',
    );
  }

  /// Optionally verify payment manually (if realtime fails)
  Future<bool> verifyPayment(String bookingId) async {
    final res = await client
        .from('bookings')
        .select('payment_status')
        .eq('id', bookingId)
        .maybeSingle();

    return (res?['payment_status'] ?? '').toString().toLowerCase() ==
        'completed';
  }
}
