import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/booking/data/services/payment_services.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_payment_provider.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/payment_flow_provider.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_expiry_countdown.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:url_launcher/url_launcher.dart';

enum _PaymentMode { nativeMno, nativeBank, hosted }

class PaymentScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const PaymentScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _paymentLaunched = false;
  bool _isHostedProcessing = false;
  bool _isNativeSubmitting = false;
  bool _didNavigateToConfirmation = false;
  bool _prefilledFields = false;

  _PaymentMode _mode = _PaymentMode.nativeMno;

  // MNO fields
  final TextEditingController _mnoAccountCtrl = TextEditingController();
  String _mnoProvider = 'Tigo';

  // Bank fields
  final TextEditingController _bankAccountCtrl = TextEditingController();
  final TextEditingController _bankMobileCtrl = TextEditingController();
  final TextEditingController _bankOtpCtrl = TextEditingController();
  final TextEditingController _bankMerchantNameCtrl = TextEditingController();
  String _bankProvider = 'CRDB';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(analyticsServiceProvider)
          .track('payment_open', params: {'booking_id': widget.bookingId});
    });
  }

  @override
  void dispose() {
    _mnoAccountCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankMobileCtrl.dispose();
    _bankOtpCtrl.dispose();
    _bankMerchantNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchPayment(String url) async {
    if (_paymentLaunched) return;
    _paymentLaunched = true;

    setState(() => _isHostedProcessing = true);
    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppBrowserView,
        webViewConfiguration: const WebViewConfiguration(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open hosted checkout page.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isHostedProcessing = false);
      }
    }
  }

  bool _isBookingExpired(Booking booking) {
    return booking.expiresAt != null &&
        DateTime.now().isAfter(booking.expiresAt!);
  }

  Future<void> _startHostedCheckout(Booking booking) async {
    if (_isBookingExpired(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This booking hold has expired.')),
      );
      return;
    }

    _paymentLaunched = false;
    await ref
        .read(paymentFlowProvider.notifier)
        .startCheckout(widget.bookingId);
  }

  Future<void> _startNativeCheckout(
      Booking booking, NativePaymentMethod method) async {
    if (_isNativeSubmitting) return;

    if (_isBookingExpired(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This booking hold has expired.')),
      );
      return;
    }

    final amount = booking.totalPrice;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid booking amount.')),
      );
      return;
    }

    setState(() => _isNativeSubmitting = true);
    try {
      final service = ref.read(paymentServiceProvider);
      final result = await service.createNativeCheckout(
        bookingId: booking.id,
        method: method,
        amount: amount,
        mnoAccountNumber: _mnoAccountCtrl.text.trim(),
        mnoProvider: _mnoProvider,
        bankProvider: _bankProvider,
        bankMerchantAccountNumber: _bankAccountCtrl.text.trim(),
        bankMerchantMobileNumber: _bankMobileCtrl.text.trim(),
        bankOtp: _bankOtpCtrl.text.trim(),
        bankMerchantName: _bankMerchantNameCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Payment initiated. Complete confirmation on your provider prompt.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isNativeSubmitting = false);
      }
    }
  }

  Widget _buildMethodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('MNO (In-App)'),
          selected: _mode == _PaymentMode.nativeMno,
          onSelected: (_) => setState(() => _mode = _PaymentMode.nativeMno),
        ),
        ChoiceChip(
          label: const Text('Bank (In-App)'),
          selected: _mode == _PaymentMode.nativeBank,
          onSelected: (_) => setState(() => _mode = _PaymentMode.nativeBank),
        ),
        ChoiceChip(
          label: const Text('Hosted Checkout'),
          selected: _mode == _PaymentMode.hosted,
          onSelected: (_) => setState(() => _mode = _PaymentMode.hosted),
        ),
      ],
    );
  }

  Widget _buildMnoForm(Booking booking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _mnoAccountCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone / Account Number',
            hintText: 'e.g. 2557XXXXXXXX',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _mnoProvider,
          items: const [
            DropdownMenuItem(value: 'Airtel', child: Text('Airtel')),
            DropdownMenuItem(value: 'Tigo', child: Text('Tigo')),
            DropdownMenuItem(value: 'Halopesa', child: Text('Halopesa')),
            DropdownMenuItem(value: 'Azampesa', child: Text('Azampesa')),
            DropdownMenuItem(value: 'Mpesa', child: Text('Mpesa')),
          ],
          onChanged: (v) => setState(() => _mnoProvider = v ?? 'Tigo'),
          decoration: const InputDecoration(labelText: 'Provider'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isNativeSubmitting
                ? null
                : () => _startNativeCheckout(booking, NativePaymentMethod.mno),
            child: const Text('Pay In App (MNO)'),
          ),
        ),
      ],
    );
  }

  Widget _buildBankForm(Booking booking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _bankProvider,
          items: const [
            DropdownMenuItem(value: 'CRDB', child: Text('CRDB')),
            DropdownMenuItem(value: 'NMB', child: Text('NMB')),
          ],
          onChanged: (v) => setState(() => _bankProvider = v ?? 'CRDB'),
          decoration: const InputDecoration(labelText: 'Bank Provider'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankAccountCtrl,
          decoration:
              const InputDecoration(labelText: 'Merchant Account Number'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankMobileCtrl,
          keyboardType: TextInputType.phone,
          decoration:
              const InputDecoration(labelText: 'Merchant Mobile Number'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankMerchantNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Merchant Name (Optional)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankOtpCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'OTP'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isNativeSubmitting
                ? null
                : () => _startNativeCheckout(booking, NativePaymentMethod.bank),
            child: const Text('Pay In App (Bank)'),
          ),
        ),
      ],
    );
  }

  Widget _buildHostedSection(Booking booking, PaymentFlowState flowState) {
    if (flowState.checkoutUrl != null && !_paymentLaunched) {
      Future.microtask(() => _launchPayment(flowState.checkoutUrl!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: flowState.state == CheckoutState.loading
                ? null
                : () => _startHostedCheckout(booking),
            child: const Text('Open Hosted Checkout'),
          ),
        ),
        if (_isHostedProcessing) ...[
          const SizedBox(height: 8),
          const Text('Opening payment page...'),
        ],
        if (flowState.state == CheckoutState.error) ...[
          const SizedBox(height: 8),
          Text(
            userMessageForError(flowState.errorMessage ?? 'checkout_error'),
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(paymentFlowProvider);
    final bookingStream =
        ref.watch(bookingPaymentStreamProvider(widget.bookingId));

    ref.listen(bookingPaymentStreamProvider(widget.bookingId), (_, next) {
      next.whenData((booking) {
        final isDone = booking.paymentStatus == PaymentStatusEnum.completed &&
            booking.status == BookingStatusEnum.confirmed;
        if (isDone && !_didNavigateToConfirmation && context.mounted) {
          _didNavigateToConfirmation = true;
          ref
              .read(analyticsServiceProvider)
              .track('payment_success', params: {'booking_id': booking.id});
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.push('${RouteNames.bookingConfirmation}/${booking.id}');
          });
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: bookingStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(userMessageForError(e))),
        data: (booking) {
          final isPaid = booking.paymentStatus == PaymentStatusEnum.completed &&
              booking.status == BookingStatusEnum.confirmed;

          if (!_prefilledFields) {
            _prefilledFields = true;
            _mnoAccountCtrl.text = booking.user.phone;
            _bankMobileCtrl.text = booking.user.phone;
            _bankMerchantNameCtrl.text = booking.user.name;
          }

          return Column(
            children: [
              if (flowState.state == CheckoutState.loading ||
                  _isNativeSubmitting)
                const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Amount: ${booking.totalPrice?.toStringAsFixed(2) ?? '--'} TZS',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (!isPaid && booking.expiresAt != null)
                      BookingExpiryCountdown(expiresAt: booking.expiresAt!),
                    const SizedBox(height: 16),
                    if (!isPaid) ...[
                      _buildMethodSelector(),
                      const SizedBox(height: 16),
                      if (_mode == _PaymentMode.nativeMno)
                        _buildMnoForm(booking),
                      if (_mode == _PaymentMode.nativeBank)
                        _buildBankForm(booking),
                      if (_mode == _PaymentMode.hosted)
                        _buildHostedSection(booking, flowState),
                    ] else
                      const Text('Payment confirmed. Redirecting...'),
                  ],
                ),
              ),
              Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  children: [
                    Text(
                      'Payment Status: ${booking.paymentStatus.name.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                    ),
                    if (!isPaid)
                      const Text('Waiting for payment confirmation...'),
                    if (isPaid) const Text('Payment confirmed! Redirecting...'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
