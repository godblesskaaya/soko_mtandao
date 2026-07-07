// lib/features/management/presentation/pages/manager_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // Add intl to your pubspec.yaml
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_payment_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';
import 'package:soko_mtandao/features/management/presentation/widgets/active_hotel_context_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerPaymentsScreen extends ConsumerStatefulWidget {
  final String hotelId;

  const ManagerPaymentsScreen({super.key, required this.hotelId});

  @override
  ConsumerState<ManagerPaymentsScreen> createState() =>
      _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState extends ConsumerState<ManagerPaymentsScreen> {
  static const int _pageSize = 20;
  int _page = 1;
  String _sortBy = 'settled_at';
  bool _sortAsc = false;
  String? _settlementStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  void _syncActiveHotelSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedHotelId = ref.read(selectedManagerHotelIdProvider);
      if (selectedHotelId == widget.hotelId) return;
      ref.read(selectedManagerHotelIdProvider.notifier).state = widget.hotelId;
    });
  }

  ManagerPaymentListQuery get _query => ManagerPaymentListQuery(
    hotelId: widget.hotelId,
    page: _page,
    limit: _pageSize,
    sortBy: _sortBy,
    sortAscending: _sortAsc,
    settlementStatus: _settlementStatus,
    startDate: _startDate,
    endDate: _endDate,
  );

  @override
  void initState() {
    super.initState();
    _syncActiveHotelSelection();
  }

  @override
  void didUpdateWidget(covariant ManagerPaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotelId != widget.hotelId) {
      _syncActiveHotelSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(managerPaymentsPageProvider(_query));
    final walletAsync = ref.watch(managerWalletSummaryProvider(widget.hotelId));
    final readinessAsync =
        ref.watch(hotelPayoutReadinessProvider(widget.hotelId));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActiveHotelContextBar(
            activeHotelId: widget.hotelId,
            routeName: 'managerPayments',
            subtitle: 'You are viewing payouts and settlements for this hotel.',
          ),
          _buildHeader(context, readinessAsync),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(managerPaymentsPageProvider(_query));
                ref.invalidate(hotelPayoutReadinessProvider(widget.hotelId));
                try {
                  await ref
                      .read(managerPaymentsPageProvider(_query).future)
                      .timeout(const Duration(seconds: 8));
                } catch (_) {}
              },
              child: paymentsAsync.when(
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Fetching financial records...'),
                    ],
                  ),
                ),
                error: (err, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 200),
                    Center(
                      child: _ErrorState(
                        message: userMessageForError(err),
                        onRetry: () =>
                            ref.invalidate(managerPaymentsPageProvider(_query)),
                      ),
                    ),
                  ],
                ),
                data: (payments) {
                  if (payments.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('No payment history found.')),
                      ],
                    );
                  }

                  final totalRevenue = payments.fold(
                    0.0,
                    (sum, p) => sum + p.amount,
                  );
                  final hasNext = payments.length == _pageSize;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Summary Cards
                      SliverToBoxAdapter(
                        child: walletAsync.when(
                          data: (wallet) => _FinancialSummaryCards(
                            totalRevenue: wallet.totalRevenue,
                            totalCommissionPaid: wallet.totalCommissionPaid,
                            netEarnings: wallet.netEarnings,
                            availableBalance: wallet.availableBalance,
                            pendingBalance: wallet.pendingBalance,
                            paidOutAmount: wallet.paidTotal,
                          ),
                          loading: () => _FinancialSummaryCards(
                            totalRevenue: totalRevenue,
                            totalCommissionPaid: 0,
                            netEarnings: totalRevenue,
                            availableBalance: 0,
                            pendingBalance: 0,
                            paidOutAmount: 0,
                          ),
                          error: (_, __) => _FinancialSummaryCards(
                            totalRevenue: totalRevenue,
                            totalCommissionPaid: 0,
                            netEarnings: totalRevenue,
                            availableBalance: 0,
                            pendingBalance: 0,
                            paidOutAmount: 0,
                          ),
                        ),
                      ),
                      // Payments List
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final payment = payments[index];
                          return PaymentListTile(
                            payment: payment,
                            onClose: () {
                              ref.invalidate(
                                managerPaymentsPageProvider(_query),
                              );
                            },
                          );
                        }, childCount: payments.length),
                      ),
                      SliverToBoxAdapter(
                        child: _PaginationControls(
                          page: _page,
                          hasNext: hasNext,
                          onPrev: _page > 1
                              ? () => setState(() => _page -= 1)
                              : null,
                          onNext: hasNext
                              ? () => setState(() => _page += 1)
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<PayoutReadiness> readinessAsync,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Revenue & Payments',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final value = await showMenu<String>(
                        context: context,
                        position: const RelativeRect.fromLTRB(100, 100, 0, 0),
                        items: const [
                          PopupMenuItem(
                            value: 'settled_at',
                            child: Text('Sort: Settled At'),
                          ),
                          PopupMenuItem(
                            value: 'settled_amount',
                            child: Text('Sort: Amount'),
                          ),
                          PopupMenuItem(
                            value: 'customer_name',
                            child: Text('Sort: Customer'),
                          ),
                        ],
                      );
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                          _page = 1;
                        });
                      }
                    },
                    icon: const Icon(Icons.sort),
                    label: const Text('Sort'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _sortAsc = !_sortAsc;
                      _page = 1;
                    }),
                    icon: Icon(
                      _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    ),
                    label: Text(_sortAsc ? 'Asc' : 'Desc'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 3),
                        lastDate: DateTime(now.year + 1),
                        initialDateRange: _startDate != null && _endDate != null
                            ? DateTimeRange(start: _startDate!, end: _endDate!)
                            : null,
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = DateTime(
                            picked.start.year,
                            picked.start.month,
                            picked.start.day,
                          );
                          _endDate = DateTime(
                            picked.end.year,
                            picked.end.month,
                            picked.end.day,
                            23,
                            59,
                            59,
                          );
                          _page = 1;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate == null || _endDate == null
                          ? 'Date Range'
                          : '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final value = await showMenu<String?>(
                        context: context,
                        position: const RelativeRect.fromLTRB(140, 140, 0, 0),
                        items: const [
                          PopupMenuItem<String?>(
                            value: null,
                            child: Text('Status: All'),
                          ),
                          PopupMenuItem<String?>(
                            value: 'paid',
                            child: Text('Status: Paid'),
                          ),
                          PopupMenuItem<String?>(
                            value: 'available',
                            child: Text('Status: Available'),
                          ),
                          PopupMenuItem<String?>(
                            value: 'locked',
                            child: Text('Status: Locked'),
                          ),
                          PopupMenuItem<String?>(
                            value: 'pending',
                            child: Text('Status: Pending'),
                          ),
                        ],
                      );
                      setState(() {
                        _settlementStatus = value;
                        _page = 1;
                      });
                    },
                    icon: const Icon(Icons.filter_list),
                    label: Text(
                      _settlementStatus == null
                          ? 'All Status'
                          : _settlementStatus!,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openPayoutAccountDialog(context),
                    icon: const Icon(Icons.account_balance),
                    label: const Text('Payout Account'),
                  ),
                  FilledButton.icon(
                    onPressed: readinessAsync.maybeWhen(
                      data: (readiness) =>
                          readiness.ready ? () => _requestPayout(context) : null,
                      orElse: () => null,
                    ),
                    icon: const Icon(Icons.payments),
                    label: const Text('Request Payout'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        readinessAsync.when(
          data: (readiness) => _PayoutReadinessCard(
            readiness: readiness,
            onConfigure: () => _openPayoutAccountDialog(context),
          ),
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (err, _) => _PayoutReadinessCard.error(
            message: userMessageForError(err),
            onConfigure: () => _openPayoutAccountDialog(context),
          ),
        ),
      ],
    ),
  );

  Future<void> _requestPayout(BuildContext context) async {
    try {
      final batchId = await ref.read(managerRepositoryProvider).requestPayout(
            widget.hotelId,
            minimumThreshold: 0,
            provider: 'azampay_disburse',
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            batchId == null
                ? 'No available balance met payout threshold.'
                : 'Payout batch created: $batchId',
          ),
        ),
      );
      ref.invalidate(managerWalletSummaryProvider(widget.hotelId));
      ref.invalidate(hotelPayoutReadinessProvider(widget.hotelId));
      ref.invalidate(managerPaymentsPageProvider(_query));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(e))),
      );
    }
  }

  Future<void> _openPayoutAccountDialog(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _PayoutAccountDialog(hotelId: widget.hotelId),
    );
    if (saved == true) {
      ref.invalidate(hotelPayoutReadinessProvider(widget.hotelId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout account submitted for compliance review.'),
        ),
      );
    }
  }
}

// --- Payment List Tile ---
class PaymentListTile extends ConsumerWidget {
  final ManagerPayment payment;
  final VoidCallback? onClose;

  const PaymentListTile({required this.payment, super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter = NumberFormat.currency(
      symbol: 'TZS ',
      decimalDigits: 0,
    );
    final normalizedStatus = payment.status.toLowerCase();
    final isSuccess =
        normalizedStatus == 'paid' ||
        normalizedStatus == 'settled' ||
        normalizedStatus == 'available' ||
        normalizedStatus == 'success';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isSuccess
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        child: Icon(
          isSuccess ? Icons.account_balance_wallet : Icons.pending_actions,
          color: isSuccess ? Colors.green : Colors.orange,
        ),
      ),
      title: Text(
        payment.customerName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Room ${payment.roomNumber} • ${payment.nights} nights\n${DateFormat('MMM dd, yyyy').format(payment.date)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currencyFormatter.format(payment.amount),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 4),
          _StatusBadge(status: payment.status),
        ],
      ),
      onTap: () => _showPaymentDetails(context, ref, payment),
    );
  }

  void _showPaymentDetails(
    BuildContext context,
    WidgetRef ref,
    ManagerPayment payment,
  ) {
    final currencyFormatter = NumberFormat.currency(
      symbol: 'TZS ',
      decimalDigits: 0,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(width: 40, child: Divider(thickness: 4)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Transaction Details",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _detailSection("Customer Details", [
              _detailRow("Name", payment.customerName),
              _detailRow("Phone", payment.customerPhone),
              _detailRow("Ticket", "#${payment.ticketNumber}"),
            ]),
            _detailSection("Stay Information", [
              _detailRow("Room", payment.roomNumber),
              _detailRow(
                "Check-in",
                DateFormat('dd MMM yyyy').format(payment.checkIn),
              ),
              _detailRow(
                "Check-out",
                DateFormat('dd MMM yyyy').format(payment.checkOut),
              ),
              _detailRow(
                "Calculation",
                "${payment.nights} nights x ${currencyFormatter.format(payment.rate)}",
              ),
            ]),
            _detailSection("Payment Info", [
              _detailRow(
                "Settled Amount",
                currencyFormatter.format(payment.amount),
              ),
              _detailRow(
                "Payment Status",
                _formatStatus(payment.paymentStatus),
              ),
              _detailRow(
                "Provider Status",
                _formatStatus(payment.paymentProviderStatus),
              ),
              _detailRow(
                "Payment Reconciliation",
                _formatStatus(payment.paymentReconciliationStatus),
              ),
              _detailRow("Gateway Ref", payment.gatewayRef),
              _detailRow("Method", payment.paymentMethod.toUpperCase()),
            ]),
            _detailSection("Ledger Breakdown", [
              _detailRow(
                "Gross",
                currencyFormatter.format(payment.grossAmount),
              ),
              _detailRow(
                "Platform Commission",
                currencyFormatter.format(payment.commissionAmount),
              ),
              _detailRow("Tax", currencyFormatter.format(payment.taxAmount)),
              _detailRow(
                "Hotel Net",
                currencyFormatter.format(payment.hotelNetAmount),
              ),
              _detailRow(
                "Provider Fee",
                currencyFormatter.format(payment.providerFeeAmount),
              ),
              _detailRow("Settlement", _formatStatus(payment.status)),
            ]),
            _detailSection("Booking & Payout", [
              _detailRow(
                "Booking Status",
                _formatStatus(payment.bookingStatus),
              ),
              _detailRow(
                "Booking Payment",
                _formatStatus(payment.bookingPaymentStatus),
              ),
              _detailRow(
                "Booking Reconciliation",
                _formatStatus(payment.bookingReconciliationStatus),
              ),
              _detailRow("Payout Status", _formatStatus(payment.payoutStatus)),
              _detailRow(
                "Payout Provider",
                _formatStatus(payment.payoutProviderStatus),
              ),
              _detailRow("Payout Ref", payment.payoutProviderReference),
              _detailRow(
                "Payout External Ref",
                payment.payoutExternalReference,
              ),
            ]),
            _ManagerPaymentActions(
              payment: payment,
              onRequestPayout: () => _requestPayout(context, ref, payment),
              onOpenBooking: () {
                Navigator.pop(context);
                context.pushNamed(
                  'managerBookingDetail',
                  pathParameters: {'bookingId': payment.bookingId},
                );
              },
              onCopyEvidence: () => _copyEvidence(context, payment),
              onEscalate: () => _escalatePayment(context, payment),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Close Detail"),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const Divider(height: 24),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String value) {
    if (value.trim().isEmpty || value == '-') return '-';
    return value.replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _requestPayout(
    BuildContext context,
    WidgetRef ref,
    ManagerPayment payment,
  ) async {
    try {
      final readiness = await ref.read(
        hotelPayoutReadinessProvider(payment.hotelId).future,
      );
      if (!readiness.ready) {
        throw Exception('Payout blocked: ${readiness.missing.join(', ')}');
      }
      final batchId = await ref
          .read(managerRepositoryProvider)
          .requestPayout(
            payment.hotelId,
            minimumThreshold: 0,
            provider: 'azampay_disburse',
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            batchId == null
                ? 'No available balance met payout threshold.'
                : 'Payout batch created: $batchId',
          ),
        ),
      );
      onClose?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessageForError(e))));
    }
  }

  Future<void> _copyEvidence(
    BuildContext context,
    ManagerPayment payment,
  ) async {
    final evidence = [
      'ticket=${payment.ticketNumber}',
      'booking_id=${payment.bookingId}',
      'settlement_id=${payment.settlementId}',
      'settlement_status=${payment.status}',
      'payment_status=${payment.paymentStatus}',
      'payment_reconciliation=${payment.paymentReconciliationStatus}',
      'gateway_ref=${payment.gatewayRef}',
      'payout_status=${payment.payoutStatus}',
      'payout_ref=${payment.payoutProviderReference}',
      'payout_external_ref=${payment.payoutExternalReference}',
      'gross=${payment.grossAmount}',
      'hotel_net=${payment.hotelNetAmount}',
      'provider_fee=${payment.providerFeeAmount}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: evidence));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ledger evidence copied.')));
  }

  Future<void> _escalatePayment(
    BuildContext context,
    ManagerPayment payment,
  ) async {
    try {
      final disputeId = await Supabase.instance.client.rpc(
        'submit_dispute',
        params: {
          'p_ticket_number': payment.ticketNumber,
          'p_category': 'financial_reconciliation',
          'p_description':
              'Manager escalation for booking ${payment.bookingId}. '
              'Settlement ${payment.settlementId}, payment ${payment.paymentStatus}, '
              'payment reconciliation ${payment.paymentReconciliationStatus}, '
              'payout ${payment.payoutStatus}, gateway ${payment.gatewayRef}.',
        },
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Support case opened: $disputeId')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessageForError(e))));
    }
  }
}

class _ManagerPaymentActions extends StatelessWidget {
  final ManagerPayment payment;
  final VoidCallback onRequestPayout;
  final VoidCallback onOpenBooking;
  final VoidCallback onCopyEvidence;
  final VoidCallback onEscalate;

  const _ManagerPaymentActions({
    required this.payment,
    required this.onRequestPayout,
    required this.onOpenBooking,
    required this.onCopyEvidence,
    required this.onEscalate,
  });

  @override
  Widget build(BuildContext context) {
    final settlementStatus = payment.status.toLowerCase();
    final payoutStatus = payment.payoutStatus.toLowerCase();
    final needsReconciliation =
        [
          payment.bookingReconciliationStatus,
          payment.paymentReconciliationStatus,
        ].any((status) {
          final normalized = status.toLowerCase();
          return normalized != '-' && normalized != 'none';
        });
    final canRequestPayout =
        settlementStatus == 'available' &&
        (payoutStatus == '-' || payoutStatus == 'failed');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onOpenBooking,
          icon: const Icon(Icons.event_note),
          label: const Text('Open Booking'),
        ),
        OutlinedButton.icon(
          onPressed: onCopyEvidence,
          icon: const Icon(Icons.copy),
          label: const Text('Copy Evidence'),
        ),
        if (canRequestPayout)
          FilledButton.icon(
            onPressed: onRequestPayout,
            icon: const Icon(Icons.payments),
            label: const Text('Request Payout'),
          ),
        if (needsReconciliation || payoutStatus == 'provider_pending')
          FilledButton.tonalIcon(
            onPressed: onEscalate,
            icon: const Icon(Icons.support_agent),
            label: const Text('Escalate'),
          ),
      ],
    );
  }
}

// --- Supporting Widgets ---

class _PayoutReadinessCard extends StatelessWidget {
  final PayoutReadiness? readiness;
  final String? errorMessage;
  final VoidCallback onConfigure;

  const _PayoutReadinessCard({
    required this.readiness,
    required this.onConfigure,
  }) : errorMessage = null;

  const _PayoutReadinessCard.error({
    required String message,
    required this.onConfigure,
  })  : readiness = null,
        errorMessage = message;

  @override
  Widget build(BuildContext context) {
    final isReady = readiness?.ready == true;
    final statusColor = isReady ? Colors.green : Colors.orange;
    final account = readiness?.account;
    final missing = readiness?.missing ?? const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.verified_user : Icons.warning_amber_rounded,
            color: statusColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady
                      ? 'Payouts ready'
                      : 'Payout setup requires attention',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (errorMessage != null)
                  Text(errorMessage!)
                else if (isReady)
                  Text(
                    '${account?['provider_name'] ?? 'Provider'} • '
                    '${account?['account_name'] ?? 'Account'} • '
                    '${account?['currency'] ?? 'TZS'}',
                  )
                else
                  Text(
                    missing.isEmpty
                        ? 'Complete KYC and payout account review before requesting disbursement.'
                        : missing.join(' • '),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onConfigure,
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _PayoutAccountDialog extends StatefulWidget {
  final String hotelId;

  const _PayoutAccountDialog({required this.hotelId});

  @override
  State<_PayoutAccountDialog> createState() => _PayoutAccountDialogState();
}

class _PayoutAccountDialogState extends State<_PayoutAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameCtrl = TextEditingController();
  final _mobileNumberCtrl = TextEditingController();
  final _countryCodeCtrl = TextEditingController(text: 'TZ');
  final _currencyCtrl = TextEditingController(text: 'TZS');
  String _providerName = 'tigo';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _accountNameCtrl.dispose();
    _mobileNumberCtrl.dispose();
    _countryCodeCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.rpc('upsert_hotel_payout_account', params: {
        'p_hotel_id': widget.hotelId,
        'p_provider_type': 'mobile_money',
        'p_provider_name': _providerName,
        'p_account_name': _accountNameCtrl.text.trim(),
        'p_account_number': null,
        'p_mobile_number': _mobileNumberCtrl.text.trim(),
        'p_currency': _currencyCtrl.text.trim().toUpperCase(),
        'p_country_code': _countryCodeCtrl.text.trim().toUpperCase(),
        'p_provider_reference': null,
        'p_metadata': {
          'submitted_from': 'manager_payments_screen',
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        },
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForError(e))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Payout Account'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _providerName,
                  items: const [
                    DropdownMenuItem(value: 'tigo', child: Text('Tigo')),
                    DropdownMenuItem(value: 'airtel', child: Text('Airtel')),
                    DropdownMenuItem(
                      value: 'azampesa',
                      child: Text('Azampesa'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _providerName = value ?? 'tigo');
                  },
                  decoration: const InputDecoration(
                    labelText: 'Mobile Money Provider',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Legal Name',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileNumberCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Wallet Number',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _countryCodeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration:
                            const InputDecoration(labelText: 'Country Code'),
                        validator: (v) {
                          final value = (v ?? '').trim().toUpperCase();
                          return RegExp(r'^[A-Z]{2}$').hasMatch(value)
                              ? null
                              : 'Use 2 letters';
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _currencyCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration:
                            const InputDecoration(labelText: 'Currency'),
                        validator: (v) {
                          final value = (v ?? '').trim().toUpperCase();
                          return RegExp(r'^[A-Z]{3}$').hasMatch(value)
                              ? null
                              : 'Use 3 letters';
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Saving changes sends this account back to compliance review before payouts can be requested.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Submit'),
        ),
      ],
    );
  }
}

class _FinancialSummaryCards extends StatelessWidget {
  final double totalRevenue;
  final double totalCommissionPaid;
  final double netEarnings;
  final double availableBalance;
  final double pendingBalance;
  final double paidOutAmount;

  const _FinancialSummaryCards({
    required this.totalRevenue,
    required this.totalCommissionPaid,
    required this.netEarnings,
    required this.availableBalance,
    required this.pendingBalance,
    required this.paidOutAmount,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      symbol: 'TZS ',
      decimalDigits: 0,
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Total Settled Revenue",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(totalRevenue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                    'Commission',
                    currencyFormatter.format(totalCommissionPaid),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniMetric(
                    'Net',
                    currencyFormatter.format(netEarnings),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                    'Available',
                    currencyFormatter.format(availableBalance),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniMetric(
                    'Pending',
                    currencyFormatter.format(pendingBalance),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                    'Paid Out',
                    currencyFormatter.format(paidOutAmount),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color =
        normalized == 'paid' ||
            normalized == 'settled' ||
            normalized == 'available' ||
            normalized == 'success'
        ? Colors.green
        : normalized == 'pending' ||
              normalized == 'locked' ||
              normalized == 'processing' ||
              normalized == 'provider_pending'
        ? Colors.orange
        : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int page;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationControls({
    required this.page,
    required this.hasNext,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(onPressed: onPrev, child: const Text("Previous")),
          Text("Page $page"),
          OutlinedButton(
            onPressed: hasNext ? onNext : null,
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text("Try Again")),
        ],
      ),
    );
  }
}
