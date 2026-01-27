import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/delete_room.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/update_room.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
typedef RoomMutationState
    = AsyncValue<Either<Failure, ManagerRoom?>>;

class RoomMutationNotifier
    extends StateNotifier<RoomMutationState> {
  final UpdateRoom _update;
  final DeleteRoom _delete;

  RoomMutationNotifier({
    required UpdateRoom update,
    required DeleteRoom delete,
  })  : _update = update,
        _delete = delete,
        super(const AsyncData(Right(null)));

  Future<void> updateRoom(ManagerRoom room) async {
    state = const AsyncLoading();
    final result = await _update.call(room);
    state = AsyncData(result);
  }

  Future<void> deleteRoom(String roomId) async {
    state = const AsyncLoading();
    final result = await _delete.call(roomId);

    state = AsyncData(
      result.map((_) => null), // delete returns Unit
    );
  }
}

final RoomMutationProvider = StateNotifierProvider<
    RoomMutationNotifier,
    RoomMutationState>((ref) {
  return RoomMutationNotifier(
    update: ref.watch(updateRoomUseCaseProvider),
    delete: ref.watch(deleteRoomUseCaseProvider),
  );
});


final updateRoomUseCaseProvider = Provider<UpdateRoom>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return UpdateRoom(repo);
});

final deleteRoomUseCaseProvider = Provider<DeleteRoom>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return DeleteRoom(repo);
});