// lib/features/management/presentation/pages/manager_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Add intl to your pubspec.yaml
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_payment_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';
import 'package:soko_mtandao/features/management/presentation/widgets/active_hotel_context_bar.dart';

class ManagerPaymentsScreen extends ConsumerStatefulWidget {
  final String hotelId;

  const ManagerPaymentsScreen({
    super.key,
    required this.hotelId,
  });

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

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActiveHotelContextBar(
            activeHotelId: widget.hotelId,
            routeName: 'managerPayments',
            subtitle: 'You are viewing payouts and settlements for this hotel.',
          ),
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(managerPaymentsPageProvider(_query));
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
                      Text('Fetching financial records...')
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

                  final totalRevenue =
                      payments.fold(0.0, (sum, p) => sum + p.amount);
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
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final payment = payments[index];
                            return PaymentListTile(
                              payment: payment,
                              onClose: () {
                                ref.invalidate(
                                    managerPaymentsPageProvider(_query));
                              },
                            );
                          },
                          childCount: payments.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _PaginationControls(
                          page: _page,
                          hasNext: hasNext,
                          onPrev: _page > 1
                              ? () => setState(() => _page -= 1)
                              : null,
                          onNext:
                              hasNext ? () => setState(() => _page += 1) : null,
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

  Widget _buildHeader(BuildContext context) => Padding(
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
                            position:
                                const RelativeRect.fromLTRB(100, 100, 0, 0),
                            items: const [
                              PopupMenuItem(
                                  value: 'settled_at',
                                  child: Text('Sort: Settled At')),
                              PopupMenuItem(
                                  value: 'settled_amount',
                                  child: Text('Sort: Amount')),
                              PopupMenuItem(
                                  value: 'customer_name',
                                  child: Text('Sort: Customer')),
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
                        icon: Icon(_sortAsc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                        label: Text(_sortAsc ? 'Asc' : 'Desc'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 3),
                            lastDate: DateTime(now.year + 1),
                            initialDateRange:
                                _startDate != null && _endDate != null
                                    ? DateTimeRange(
                                        start: _startDate!, end: _endDate!)
                                    : null,
                          );
                          if (picked != null) {
                            setState(() {
                              _startDate = DateTime(picked.start.year,
                                  picked.start.month, picked.start.day);
                              _endDate = DateTime(picked.end.year,
                                  picked.end.month, picked.end.day, 23, 59, 59);
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
                            position:
                                const RelativeRect.fromLTRB(140, 140, 0, 0),
                            items: const [
                              PopupMenuItem<String?>(
                                  value: null, child: Text('Status: All')),
                              PopupMenuItem<String?>(
                                  value: 'paid', child: Text('Status: Paid')),
                              PopupMenuItem<String?>(
                                  value: 'available',
                                  child: Text('Status: Available')),
                              PopupMenuItem<String?>(
                                  value: 'locked',
                                  child: Text('Status: Locked')),
                              PopupMenuItem<String?>(
                                  value: 'pending',
                                  child: Text('Status: Pending')),
                            ],
                          );
                          setState(() {
                            _settlementStatus = value;
                            _page = 1;
                          });
                        },
                        icon: const Icon(Icons.filter_list),
                        label: Text(_settlementStatus == null
                            ? 'All Status'
                            : _settlementStatus!),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            final batchId = await ref
                                .read(managerRepositoryProvider)
                                .requestPayout(
                                  widget.hotelId,
                                  minimumThreshold: 0,
                                  provider: 'azampay_disburse',
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(batchId == null
                                    ? 'No available balance met payout threshold.'
                                    : 'Payout batch created: $batchId'),
                              ),
                            );
                            ref.invalidate(
                                managerWalletSummaryProvider(widget.hotelId));
                            ref.invalidate(managerPaymentsPageProvider(_query));
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(userMessageForError(e))),
                            );
                          }
                        },
                        icon: const Icon(Icons.payments),
                        label: const Text('Request Payout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// --- Payment List Tile ---
class PaymentListTile extends StatelessWidget {
  final ManagerPayment payment;
  final VoidCallback? onClose;

  const PaymentListTile({required this.payment, super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    final normalizedStatus = payment.status.toLowerCase();
    final isSuccess = normalizedStatus == 'paid' ||
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
      onTap: () => _showPaymentDetails(context, payment),
    );
  }

  void _showPaymentDetails(BuildContext context, ManagerPayment payment) {
    final currencyFormatter =
        NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

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
                child: SizedBox(width: 40, child: Divider(thickness: 4))),
            const SizedBox(height: 16),
            const Text("Transaction Details",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _detailSection("Customer Details", [
              _detailRow("Name", payment.customerName),
              _detailRow("Phone", payment.customerPhone),
              _detailRow("Ticket", "#${payment.ticketNumber}"),
            ]),
            _detailSection("Stay Information", [
              _detailRow("Room", payment.roomNumber),
              _detailRow("Check-in",
                  DateFormat('dd MMM yyyy').format(payment.checkIn)),
              _detailRow("Check-out",
                  DateFormat('dd MMM yyyy').format(payment.checkOut)),
              _detailRow("Calculation",
                  "${payment.nights} nights x ${currencyFormatter.format(payment.rate)}"),
            ]),
            _detailSection("Payment Info", [
              _detailRow(
                  "Settled Amount", currencyFormatter.format(payment.amount)),
              _detailRow("Gateway Ref", payment.gatewayRef),
              _detailRow("Method", payment.paymentMethod.toUpperCase()),
            ]),
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
        Text(title,
            style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
                fontSize: 12)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          SelectableText(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// --- Supporting Widgets ---

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
    final currencyFormatter =
        NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
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
            const Text("Total Settled Revenue",
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(totalRevenue),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniMetric('Commission',
                      currencyFormatter.format(totalCommissionPaid)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _miniMetric('Net', currencyFormatter.format(netEarnings)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                      'Available', currencyFormatter.format(availableBalance)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniMetric(
                      'Pending', currencyFormatter.format(pendingBalance)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                      'Paid Out', currencyFormatter.format(paidOutAmount)),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
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
    final color = normalized == 'paid' ||
            normalized == 'settled' ||
            normalized == 'available' ||
            normalized == 'success'
        ? Colors.green
        : normalized == 'pending' ||
                normalized == 'locked' ||
                normalized == 'processing'
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
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
              onPressed: hasNext ? onNext : null, child: const Text("Next")),
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
          const Icon(Icons.warning_amber_rounded,
              size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text("Try Again")),
        ],
      ),
    );
  }
}
