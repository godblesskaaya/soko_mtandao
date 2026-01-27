import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetPayments implements UseCase<List<ManagerPayment>, String> {
  final ManagerRepository repository;
  GetPayments(this.repository);

  @override
  Future<Either<Failure, List<ManagerPayment>>> call(String hotelId) async {
    try {
      List<ManagerPayment> managerPayments = await repository.getPayments(hotelId);
      return Right(managerPayments);
    } catch (e, stackTrace) {
      print("Server error fetching payments: $e");
      print(stackTrace);
      return Left(ServerFailure("Failed to fetch payments: $e"));
    }
  }
}

