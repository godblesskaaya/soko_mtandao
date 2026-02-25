import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetPayments implements UseCase<List<ManagerPayment>, PaymentListParams> {
  final ManagerRepository repository;
  GetPayments(this.repository);

  @override
  Future<Either<Failure, List<ManagerPayment>>> call(PaymentListParams params) async {
    try {
      List<ManagerPayment> managerPayments = await repository.getPayments(
        params.hotelId,
        filters: params.filters,
      );
      return Right(managerPayments);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'GetPayments.call');
      return Left(ServerFailure("Failed to fetch payments"));
    }
  }
}

class PaymentListParams {
  final String hotelId;
  final Map<String, dynamic>? filters;

  const PaymentListParams({
    required this.hotelId,
    this.filters,
  });
}

