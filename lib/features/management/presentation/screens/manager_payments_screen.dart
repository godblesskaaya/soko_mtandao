// lib/features/management/presentation/pages/manager_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Add intl to your pubspec.yaml
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_payment_provider.dart';

class ManagerPaymentsScreen extends ConsumerStatefulWidget {
  final String hotelId;

  const ManagerPaymentsScreen({
    super.key,
    required this.hotelId,
  });

  @override
  ConsumerState<ManagerPaymentsScreen> createState() => _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState extends ConsumerState<ManagerPaymentsScreen> {
  static const int _pageSize = 20;
  int _page = 1;
  String _sortBy = 'settled_at';
  bool _sortAsc = false;
  String? _settlementStatus;

  ManagerPaymentListQuery get _query => ManagerPaymentListQuery(
        hotelId: widget.hotelId,
        page: _page,
        limit: _pageSize,
        sortBy: _sortBy,
        sortAscending: _sortAsc,
        settlementStatus: _settlementStatus,
      );

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(managerPaymentsPageProvider(_query));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        onRetry: () => ref.invalidate(managerPaymentsPageProvider(_query)),
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
                        child: _FinancialSummaryCards(totalRevenue: totalRevenue),
                      ),
                      // Payments List
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final payment = payments[index];
                            return PaymentListTile(
                              payment: payment,
                              onClose: () {
                                ref.invalidate(managerPaymentsPageProvider(_query));
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
                          onPrev: _page > 1 ? () => setState(() => _page -= 1) : null,
                          onNext: hasNext ? () => setState(() => _page += 1) : null,
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
                            position: const RelativeRect.fromLTRB(100, 100, 0, 0),
                            items: const [
                              PopupMenuItem(value: 'settled_at', child: Text('Sort: Settled At')),
                              PopupMenuItem(value: 'settled_amount', child: Text('Sort: Amount')),
                              PopupMenuItem(value: 'customer_name', child: Text('Sort: Customer')),
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
                        icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
                        label: Text(_sortAsc ? 'Asc' : 'Desc'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final value = await showMenu<String?>(
                            context: context,
                            position: const RelativeRect.fromLTRB(140, 140, 0, 0),
                            items: const [
                              PopupMenuItem<String?>(value: null, child: Text('Status: All')),
                              PopupMenuItem<String?>(value: 'settled', child: Text('Status: Settled')),
                              PopupMenuItem<String?>(value: 'success', child: Text('Status: Success')),
                              PopupMenuItem<String?>(value: 'pending', child: Text('Status: Pending')),
                            ],
                          );
                          setState(() {
                            _settlementStatus = value;
                            _page = 1;
                          });
                        },
                        icon: const Icon(Icons.filter_list),
                        label: Text(_settlementStatus == null ? 'All Status' : _settlementStatus!),
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
    final currencyFormatter = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    final isSuccess = payment.status.toLowerCase() == 'settled' || payment.status.toLowerCase() == 'success';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isSuccess ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
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
    final currencyFormatter = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    
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
            const Center(child: SizedBox(width: 40, child: Divider(thickness: 4))),
            const SizedBox(height: 16),
            const Text("Transaction Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            _detailSection("Customer Details", [
              _detailRow("Name", payment.customerName),
              _detailRow("Phone", payment.customerPhone),
              _detailRow("Ticket", "#${payment.ticketNumber}"),
            ]),
            
            _detailSection("Stay Information", [
              _detailRow("Room", payment.roomNumber),
              _detailRow("Check-in", DateFormat('dd MMM yyyy').format(payment.checkIn)),
              _detailRow("Check-out", DateFormat('dd MMM yyyy').format(payment.checkOut)),
              _detailRow("Calculation", "${payment.nights} nights x ${currencyFormatter.format(payment.rate)}"),
            ]),
            
            _detailSection("Payment Info", [
              _detailRow("Settled Amount", currencyFormatter.format(payment.amount)),
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
        Text(title, style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12)),
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
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// --- Supporting Widgets ---

class _FinancialSummaryCards extends StatelessWidget {
  final double totalRevenue;
  const _FinancialSummaryCards({required this.totalRevenue});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
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
            const Text("Total Settled Revenue", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(totalRevenue),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white54, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "This balance includes all payments cleared by the gateway for your hotel rooms.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.toLowerCase() == 'settled' ? Colors.green : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
          OutlinedButton(onPressed: hasNext ? onNext : null, child: const Text("Next")),
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
          const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text("Try Again")),
        ],
      ),
    );
  }
}
