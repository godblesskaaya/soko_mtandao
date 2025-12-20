import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_payments.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

final getPaymentsUsecaseProvider = Provider<GetPayments>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetPayments(repo);
});

final managerPaymentsProvider = FutureProvider.family<
    List<ManagerPayment>, String>((ref, hotelId) {
  final getPaymentsUsecase = ref.watch(getPaymentsUsecaseProvider);
  return getPaymentsUsecase.call(hotelId).then((result) =>
      result.fold((failure) => throw failure, (data) => data));
});
