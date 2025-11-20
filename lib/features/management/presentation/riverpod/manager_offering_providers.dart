// presentation/riverpod/offerings/offering_providers.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/usecases/offerings/add_offering.dart';
import 'package:soko_mtandao/features/management/domain/usecases/offerings/get_offerings_for_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

final getOfferingsForHotelProvider = Provider<GetOfferingsForHotel>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetOfferingsForHotel(repo);
});

final offeringsProvider = FutureProvider.family<List<ManagerOffering>, String>((ref, hotelId) {
  return ref.watch(getOfferingsForHotelProvider).call(hotelId).then((result) =>
    result.fold((failure) => throw failure, (offerings) => offerings)
  );
});

final addOfferingUseCaseProvider = Provider<AddOffering>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return AddOffering(repo);
});

final addOfferingProvider = StateNotifierProvider<AddOfferingNotifier, AsyncValue<Either<Failure, ManagerOffering>?>>((ref) {
  final usecase = ref.read(addOfferingUseCaseProvider);
  return AddOfferingNotifier(usecase);
});

class AddOfferingNotifier extends StateNotifier<AsyncValue<Either<Failure, ManagerOffering>?>> {
  final AddOffering _useCase;

  AddOfferingNotifier(this._useCase) : super( const AsyncData(null));

  Future<void> addOffering(ManagerOffering offering) async {
    state = const AsyncLoading();
    final result = await _useCase(offering);
    state = AsyncData(result);
  }
}