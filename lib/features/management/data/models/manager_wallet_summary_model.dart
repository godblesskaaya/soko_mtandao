import 'package:soko_mtandao/features/management/domain/entities/manager_wallet_summary.dart';

class ManagerWalletSummaryModel extends ManagerWalletSummary {
  const ManagerWalletSummaryModel({
    required super.hotelId,
    required super.totalRevenue,
    required super.totalCommissionPaid,
    required super.netEarnings,
    required super.pendingBalance,
    required super.availableBalance,
    required super.lockedBalance,
    required super.paidTotal,
    required super.lifetimeEarnings,
  });

  static double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;

  factory ManagerWalletSummaryModel.fromJson(Map<String, dynamic> json) {
    return ManagerWalletSummaryModel(
      hotelId: (json['hotel_id'] ?? '').toString(),
      totalRevenue: _num(json['total_revenue']),
      totalCommissionPaid: _num(json['total_commission_paid']),
      netEarnings: _num(json['net_earnings']),
      pendingBalance: _num(json['pending_balance']),
      availableBalance: _num(json['available_balance']),
      lockedBalance: _num(json['locked_balance']),
      paidTotal: _num(json['paid_total']),
      lifetimeEarnings: _num(json['lifetime_earnings']),
    );
  }
}
