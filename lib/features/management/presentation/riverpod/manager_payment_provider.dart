import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_payments.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

class ManagerPaymentListQuery {
  final String hotelId;
  final int page;
  final int limit;
  final String sortBy;
  final bool sortAscending;
  final String? settlementStatus;

  const ManagerPaymentListQuery({
    required this.hotelId,
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'settled_at',
    this.sortAscending = false,
    this.settlementStatus,
  });

  int get offset => (page - 1) * limit;

  Map<String, dynamic> get filters => {
        'limit': limit,
        'offset': offset,
        'sort_by': sortBy,
        'sort_asc': sortAscending,
        if (settlementStatus != null && settlementStatus!.trim().isNotEmpty)
          'settlement_status': settlementStatus!.trim(),
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
            settlementStatus == other.settlementStatus;
  }

  @override
  int get hashCode =>
      Object.hash(hotelId, page, limit, sortBy, sortAscending, settlementStatus);
}

final getPaymentsUsecaseProvider = Provider<GetPayments>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetPayments(repo);
});

final managerPaymentsPageProvider =
    FutureProvider.family<List<ManagerPayment>, ManagerPaymentListQuery>((ref, query) {
  final getPaymentsUsecase = ref.watch(getPaymentsUsecaseProvider);
  return getPaymentsUsecase
      .call(PaymentListParams(hotelId: query.hotelId, filters: query.filters))
      .then((result) =>
      result.fold((failure) => throw failure, (data) => data));
});

final managerPaymentsProvider =
    FutureProvider.family<List<ManagerPayment>, String>((ref, hotelId) {
  return ref.watch(managerPaymentsPageProvider(ManagerPaymentListQuery(hotelId: hotelId)).future);
});
