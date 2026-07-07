import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/booking/data/services/payment_services.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_payment_provider.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/payment_flow_provider.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_expiry_countdown.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isOtpRequesting = false;
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

  String _formatMoney(double? amount) {
    if (amount == null) return '-';
    return '${amount.toStringAsFixed(2)} TZS';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _statusText(String value) {
    return value.replaceAll('_', ' ').toUpperCase();
  }

  Widget _buildPaymentEvidenceCard(Booking booking) {
    final latestPayment = booking.latestPayment ?? const <String, dynamic>{};
    final gatewayRef =
        (latestPayment['payment_gateway_ref'] ??
                latestPayment['provider_reference'] ??
                '-')
            .toString();
    final externalId = (latestPayment['external_id'] ?? '-').toString();
    final providerStatus =
        (latestPayment['provider_status'] ?? latestPayment['status'] ?? '-')
            .toString();
    final paidAmount =
        (latestPayment['amount_received'] as num?)?.toDouble() ??
        booking.amountPaid;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Evidence',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _evidenceRow('Booking', _statusText(booking.rawStatus)),
            _evidenceRow('Payment', _statusText(booking.rawPaymentStatus)),
            _evidenceRow(
              'Provider',
              providerStatus == '-' ? '-' : _statusText(providerStatus),
            ),
            _evidenceRow(
              'Reconciliation',
              _statusText(booking.reconciliationStatus),
            ),
            _evidenceRow('Amount received', _formatMoney(paidAmount)),
            _evidenceRow('Gateway ref', gatewayRef),
            _evidenceRow('External ref', externalId),
            _evidenceRow(
              'Initiated',
              _formatDateTime(booking.paymentInitiatedAt),
            ),
            _evidenceRow(
              'Provider grace until',
              _formatDateTime(booking.providerGraceExpiresAt),
            ),
            _evidenceRow(
              'Completed',
              _formatDateTime(booking.paymentCompletedAt),
            ),
            const SizedBox(height: 8),
            _PaymentCustomerActions(
              booking: booking,
              onRefresh: () => ref.invalidate(
                bookingPaymentStreamProvider(widget.bookingId),
              ),
              onCopyEvidence: () => _copyPaymentEvidence(booking),
              onEscalate: () => _escalatePaymentIssue(booking),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPaymentEvidence(Booking booking) async {
    final latestPayment = booking.latestPayment ?? const <String, dynamic>{};
    final evidence = [
      'ticket=${booking.ticketNumber ?? '-'}',
      'booking_id=${booking.id}',
      'booking_status=${booking.rawStatus}',
      'payment_status=${booking.rawPaymentStatus}',
      'reconciliation=${booking.reconciliationStatus}',
      'gateway_ref=${latestPayment['payment_gateway_ref'] ?? '-'}',
      'provider_ref=${latestPayment['provider_reference'] ?? '-'}',
      'external_id=${latestPayment['external_id'] ?? '-'}',
      'amount_paid=${booking.amountPaid ?? latestPayment['amount_received'] ?? '-'}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: evidence));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Payment evidence copied.')));
  }

  Future<void> _escalatePaymentIssue(Booking booking) async {
    final ticket = (booking.ticketNumber ?? '').trim();
    if (ticket.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket number is not available yet.')),
      );
      return;
    }

    final latestPayment = booking.latestPayment ?? const <String, dynamic>{};
    try {
      final disputeId = await Supabase.instance.client.rpc(
        'submit_dispute',
        params: {
          'p_ticket_number': ticket,
          'p_category': 'payment_reconciliation',
          'p_description':
              'Customer payment issue for booking ${booking.id}. '
              'Booking ${booking.rawStatus}, payment ${booking.rawPaymentStatus}, '
              'reconciliation ${booking.reconciliationStatus}, '
              'gateway ${latestPayment['payment_gateway_ref'] ?? '-'}, '
              'external ${latestPayment['external_id'] ?? '-'}.',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Support case opened: $disputeId')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessageForError(e))));
    }
  }

  Widget _evidenceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
        .startCheckout(widget.bookingId, ticketNumber: booking.ticketNumber);
  }

  Future<void> _startNativeCheckout(
    Booking booking,
    NativePaymentMethod method,
  ) async {
    if (_isNativeSubmitting) return;

    if (_isBookingExpired(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This booking hold has expired.')),
      );
      return;
    }

    final amount = booking.totalPrice;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid booking amount.')));
      return;
    }

    setState(() => _isNativeSubmitting = true);
    try {
      final service = ref.read(paymentServiceProvider);
      final result = await service.createNativeCheckout(
        bookingId: booking.id,
        ticketNumber: booking.ticketNumber,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessageForError(e))));
    } finally {
      if (mounted) {
        setState(() => _isNativeSubmitting = false);
      }
    }
  }

  Future<void> _requestBankOtp(Booking booking) async {
    if (_isOtpRequesting) return;

    if (_isBookingExpired(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This booking hold has expired.')),
      );
      return;
    }

    setState(() => _isOtpRequesting = true);
    try {
      final service = ref.read(paymentServiceProvider);
      final result = await service.generateBankOtp(
        bookingId: booking.id,
        ticketNumber: booking.ticketNumber,
        provider: _bankProvider,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'OTP requested. Check the bank-registered mobile number.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessageForError(e))));
    } finally {
      if (mounted) {
        setState(() => _isOtpRequesting = false);
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
          initialValue: _mnoProvider,
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
          initialValue: _bankProvider,
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
          decoration: const InputDecoration(
            labelText: 'Merchant Account Number',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankMobileCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Merchant Mobile Number',
          ),
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
          decoration: InputDecoration(
            labelText: 'OTP',
            suffixIcon: TextButton(
              onPressed:
                  _isOtpRequesting ? null : () => _requestBankOtp(booking),
              child: _isOtpRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate'),
            ),
          ),
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
    final bookingStream = ref.watch(
      bookingPaymentStreamProvider(widget.bookingId),
    );

    ref.listen(bookingPaymentStreamProvider(widget.bookingId), (_, next) {
      next.whenData((booking) {
        final isDone =
            booking.paymentStatus == PaymentStatusEnum.completed &&
            booking.status == BookingStatusEnum.confirmed;
        if (isDone && !_didNavigateToConfirmation && context.mounted) {
          _didNavigateToConfirmation = true;
          ref.read(bookingCartProvider.notifier).clearCart();
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
          final isPaid =
              booking.paymentStatus == PaymentStatusEnum.completed &&
              booking.status == BookingStatusEnum.confirmed;
          final totalAmount = booking.totalPrice ?? 0;
          final roomCount = booking.bookingCart.totalItems;
          final roomNights = booking.bookingCart.bookings.fold<int>(
            0,
            (sum, item) =>
                sum +
                item.items.length *
                    stayNightsInclusive(item.startDate, item.endDate),
          );

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
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount to Pay',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${totalAmount.toStringAsFixed(2)} TZS',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text('Rooms: $roomCount'),
                            Text('Room-nights: $roomNights'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentEvidenceCard(booking),
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
                      'Payment Status: ${_statusText(booking.rawPaymentStatus)}',
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

class _PaymentCustomerActions extends StatelessWidget {
  final Booking booking;
  final VoidCallback onRefresh;
  final VoidCallback onCopyEvidence;
  final VoidCallback onEscalate;

  const _PaymentCustomerActions({
    required this.booking,
    required this.onRefresh,
    required this.onCopyEvidence,
    required this.onEscalate,
  });

  @override
  Widget build(BuildContext context) {
    final paymentStatus = booking.rawPaymentStatus.toLowerCase();
    final bookingStatus = booking.rawStatus.toLowerCase();
    final reconciliationStatus = booking.reconciliationStatus.toLowerCase();
    final needsEscalation =
        paymentStatus == 'failed' ||
        bookingStatus == 'payment_reconciliation' ||
        (reconciliationStatus.isNotEmpty &&
            reconciliationStatus != '-' &&
            reconciliationStatus != 'none');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        OutlinedButton.icon(
          onPressed: onCopyEvidence,
          icon: const Icon(Icons.copy),
          label: const Text('Copy Evidence'),
        ),
        if (needsEscalation)
          FilledButton.tonalIcon(
            onPressed: onEscalate,
            icon: const Icon(Icons.support_agent),
            label: const Text('Get Help'),
          ),
      ],
    );
  }
}
