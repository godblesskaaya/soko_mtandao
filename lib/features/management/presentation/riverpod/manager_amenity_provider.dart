import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_amenities.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

final getAmenitiesUsecaseProvider = Provider<GetAmenities>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetAmenities(repo);
});

final managerAmenitiesProvider = FutureProvider<
    List<ManagerAmenity>>((ref) async{
  final getAmenities = ref.watch(getAmenitiesUsecaseProvider);
  final result = await getAmenities.call(NoParams());
  return result.fold((failure) => throw failure, (data) => data);
});
