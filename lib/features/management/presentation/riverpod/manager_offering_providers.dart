// presentation/riverpod/offerings/offering_providers.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/usecases/offerings/add_offering.dart';
import 'package:soko_mtandao/features/management/domain/usecases/offerings/get_offering_by_id.dart';
import 'package:soko_mtandao/features/management/domain/usecases/offerings/get_offerings_for_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

class ManagerOfferingListQuery {
  final String hotelId;
  final int page;
  final int limit;
  final String sortBy;
  final bool sortAscending;
  final bool? isAvailable;

  const ManagerOfferingListQuery({
    required this.hotelId,
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'title',
    this.sortAscending = true,
    this.isAvailable,
  });

  int get offset => (page - 1) * limit;

  Map<String, dynamic> get filters => {
        'limit': limit,
        'offset': offset,
        'sort_by': sortBy,
        'sort_asc': sortAscending,
        if (isAvailable != null) 'is_available': isAvailable,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ManagerOfferingListQuery &&
            runtimeType == other.runtimeType &&
            hotelId == other.hotelId &&
            page == other.page &&
            limit == other.limit &&
            sortBy == other.sortBy &&
            sortAscending == other.sortAscending &&
            isAvailable == other.isAvailable;
  }

  @override
  int get hashCode =>
      Object.hash(hotelId, page, limit, sortBy, sortAscending, isAvailable);
}

final getOfferingsForHotelProvider = Provider<GetOfferingsForHotel>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetOfferingsForHotel(repo);
});

final offeringsPageProvider = FutureProvider.family<List<ManagerOffering>, ManagerOfferingListQuery>((ref, query) {
  return ref
      .watch(getOfferingsForHotelProvider)
      .call(OfferingListParams(hotelId: query.hotelId, filters: query.filters))
      .then((result) => result.fold((failure) => throw failure, (offerings) => offerings));
});

final offeringsProvider = FutureProvider.family<List<ManagerOffering>, String>((ref, hotelId) {
  return ref.watch(offeringsPageProvider(ManagerOfferingListQuery(hotelId: hotelId)).future);
});

final getOfferingDetailsUseCaseProvider = Provider<GetOfferingsById>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetOfferingsById(repo);
});

final offeringDetailsProvider = FutureProvider.family<ManagerOffering, String>((ref, offeringId) {
  return ref.watch(getOfferingDetailsUseCaseProvider).call(offeringId).then((result) => 
    result.fold(
      (failure) => throw failure,
      (offering) => offering,
    ),
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
