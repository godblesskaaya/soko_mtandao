import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';

class PaymentService {
  final Dio dio;
  final SupabaseClient client;

  PaymentService({required this.dio, required this.client});

  /// Calls the Supabase Edge Function to initiate AzamPay hosted checkout
  Future<String> createHostedCheckout({
    required String bookingId,
    String? successRedirect,
    String? failRedirect,
  }) async {
    final url = '${AppConfig.supabaseFunctionsBaseUrl}/create_checkout';
    final payload = {
      'booking_id': bookingId,
      'redirectSuccessURL':
          successRedirect ?? '${AppConfig.appBaseUrl}/payment-success/$bookingId',
      'redirectFailURL':
          failRedirect ?? '${AppConfig.appBaseUrl}/payment-failed',
    };

    final response = await dio.post(url, data: payload);

    if (response.statusCode == 200 &&
        response.data != null &&
        response.data['checkoutUrl'] != null) {
      return response.data['checkoutUrl'];
    } else {
      throw Exception('Failed to create AzamPay checkout');
    }
  }

  /// Optionally verify payment manually (if realtime fails)
  Future<bool> verifyPayment(String bookingId) async {
    final res = await client
        .from('bookings')
        .select('payment_status')
        .eq('id', bookingId)
        .maybeSingle();

    return (res?['payment_status'] ?? '').toString().toLowerCase() == 'paid';
  }
}
