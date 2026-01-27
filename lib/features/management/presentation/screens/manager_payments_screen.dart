// lib/features/management/presentation/pages/manager_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Add intl to your pubspec.yaml
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_payment_provider.dart';

class ManagerPaymentsScreen extends ConsumerWidget {
  final String hotelId;

  const ManagerPaymentsScreen({
    super.key,
    required this.hotelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(managerPaymentsProvider(hotelId));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.refresh(managerPaymentsProvider(hotelId).future);
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
                        message: err is Failure ? err.message : 'Connection error',
                        onRetry: () => ref.invalidate(managerPaymentsProvider(hotelId)),
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
                                // Optional: refresh after detail closes
                                ref.invalidate(managerPaymentsProvider(hotelId));
                              },
                            );
                          },
                          childCount: payments.length,
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

  Widget _buildHeader() => const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Text(
          'Revenue & Payments',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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