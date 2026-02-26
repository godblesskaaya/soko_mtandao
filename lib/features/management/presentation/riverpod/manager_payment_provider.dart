import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_wallet_summary.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_payments.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

class ManagerPaymentListQuery {
  final String hotelId;
  final int page;
  final int limit;
  final String sortBy;
  final bool sortAscending;
  final String? settlementStatus;
  final DateTime? startDate;
  final DateTime? endDate;

  const ManagerPaymentListQuery({
    required this.hotelId,
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'settled_at',
    this.sortAscending = false,
    this.settlementStatus,
    this.startDate,
    this.endDate,
  });

  int get offset => (page - 1) * limit;

  Map<String, dynamic> get filters => {
        'limit': limit,
        'offset': offset,
        'sort_by': sortBy,
        'sort_asc': sortAscending,
        if (settlementStatus != null && settlementStatus!.trim().isNotEmpty)
          'settlement_status': settlementStatus!.trim(),
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ManagerPaymentListQuery &&
            runtimeType == other.runtimeType &&
            hotelId == other.hotelId &&
            page == other.page &&
            limit == other.limit &&
            sortBy == other.sortBy &&
            sortAscending == other.sortAscending &&
            settlementStatus == other.settlementStatus &&
            startDate == other.startDate &&
            endDate == other.endDate;
  }

  @override
  int get hashCode => Object.hash(hotelId, page, limit, sortBy, sortAscending,
      settlementStatus, startDate, endDate);
}

final getPaymentsUsecaseProvider = Provider<GetPayments>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetPayments(repo);
});

final managerPaymentsPageProvider =
    FutureProvider.family<List<ManagerPayment>, ManagerPaymentListQuery>(
        (ref, query) {
  final getPaymentsUsecase = ref.watch(getPaymentsUsecaseProvider);
  return getPaymentsUsecase
      .call(PaymentListParams(hotelId: query.hotelId, filters: query.filters))
      .then(
          (result) => result.fold((failure) => throw failure, (data) => data));
});

final managerPaymentsProvider =
    FutureProvider.family<List<ManagerPayment>, String>((ref, hotelId) {
  return ref.watch(
      managerPaymentsPageProvider(ManagerPaymentListQuery(hotelId: hotelId))
          .future);
});

final managerWalletSummaryProvider =
    FutureProvider.family<ManagerWalletSummary, String>((ref, hotelId) async {
  final repo = ref.watch(managerRepositoryProvider);
  return repo.getWalletSummary(hotelId);
});

final requestPayoutProvider = FutureProvider.family<
    String?,
    ({
      String hotelId,
      double minimumThreshold,
      String provider
    })>((ref, input) async {
  final repo = ref.watch(managerRepositoryProvider);
  return repo.requestPayout(
    input.hotelId,
    minimumThreshold: input.minimumThreshold,
    provider: input.provider,
  );
});
