class ManagerWalletSummary {
  final String hotelId;
  final double totalRevenue;
  final double totalCommissionPaid;
  final double netEarnings;
  final double pendingBalance;
  final double availableBalance;
  final double lockedBalance;
  final double paidTotal;
  final double lifetimeEarnings;

  const ManagerWalletSummary({
    required this.hotelId,
    required this.totalRevenue,
    required this.totalCommissionPaid,
    required this.netEarnings,
    required this.pendingBalance,
    required this.availableBalance,
    required this.lockedBalance,
    required this.paidTotal,
    required this.lifetimeEarnings,
  });
}
