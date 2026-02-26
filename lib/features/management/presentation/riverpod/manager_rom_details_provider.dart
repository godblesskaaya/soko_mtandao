import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room_details.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/get_manager_room_details.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

final managerRoomDetailsUsecaseProvider = Provider<ManagerRoomDetails>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return ManagerRoomDetails(repo);
});

final managerRoomDetailsProvider =
    FutureProvider.family<ManagerRoomDetailsData, String>((ref, roomId) {
  final repo = ref.watch(managerRoomDetailsUsecaseProvider);
  return repo.call(roomId).then(
      (result) => result.fold((failure) => throw failure, (data) => data));
});
