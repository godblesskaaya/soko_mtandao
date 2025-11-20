import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' hide launchUrl;
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_payment_provider.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/payment_flow_provider.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const PaymentScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _paymentLaunched = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Start checkout flow immediately
    Future.microtask(() {
      ref.read(paymentFlowProvider.notifier).startCheckout(widget.bookingId);
    });
  }

  /// Launches AzamPay payment page using Chrome Custom Tabs (Android)
  /// or SafariViewController (iOS)
  Future<void> _launchPayment(String url) async {
    if (_paymentLaunched) return;
    _paymentLaunched = true;

    setState(() => _isProcessing = true);
    try {
      // await launch(
      //   url,
      //   customTabsOption: CustomTabsOption(
      //     toolbarColor: Theme.of(context).colorScheme.primary,
      //     enableUrlBarHiding: true,
      //     showPageTitle: true,
      //     enableDefaultShare: false,
      //     animation: const CustomTabsSystemAnimation.slideIn(),
      //   ),
      //   safariVCOption: const SafariViewControllerOption(
      //     preferredBarTintColor: Colors.white,
      //     preferredControlTintColor: Colors.blue,
      //     barCollapsingEnabled: true,
      //   ),
      // );

      // use url_launcher and custom tabs
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webViewConfiguration: const WebViewConfiguration());
    } catch (e) {
      debugPrint('Error launching payment tab: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open payment page.')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(paymentFlowProvider);
    final bookingStream =
        ref.watch(bookingPaymentStreamProvider(widget.bookingId));

    // Automatically redirect to confirmation page when payment is done
    ref.listen(bookingPaymentStreamProvider(widget.bookingId), (_, next) {
      next.whenData((booking) {
        final isDone = booking.paymentStatus == PaymentStatusEnum.completed &&
            booking.status == BookingStatusEnum.confirmed;
        if (isDone && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('${RouteNames.bookingConfirmation}/${booking.id}');
          });
        }
      });
    });

    // Launch payment once checkout URL is ready
    if (flowState.checkoutUrl != null && !_paymentLaunched) {
      Future.microtask(() => _launchPayment(flowState.checkoutUrl!));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: Column(
        children: [
          if (flowState.state == CheckoutState.loading)
            const LinearProgressIndicator(),

          Expanded(
            child: Center(
              child: Builder(builder: (context) {
                if (flowState.state == CheckoutState.error) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error starting checkout:\n${flowState.errorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (_isProcessing) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Opening payment page...'),
                    ],
                  );
                }

                if (flowState.checkoutUrl == null) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Preparing payment...'),
                    ],
                  );
                }

                return const Text('Payment launched — complete it in browser.');
              }),
            ),
          ),

          // Real-time booking payment status
          bookingStream.when(
            data: (booking) {
              final statusText = booking.paymentStatus.name.toUpperCase();
              final isPaid =
                  booking.paymentStatus == PaymentStatusEnum.completed &&
                      booking.status == BookingStatusEnum.confirmed;

              return Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  children: [
                    Text(
                      'Payment Status: $statusText',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                    ),
                    if (!isPaid)
                      const Text('Waiting for payment confirmation...'),
                    if (isPaid)
                      const Text('Payment confirmed! Redirecting...'),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Error: $e'),
            ),
          ),
        ],
      ),
    );
  }
}
