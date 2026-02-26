import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/get_manager_room_details.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/update_room_status.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_rom_details_provider.dart';

final managerRoomActionsProvider =
    AsyncNotifierProvider<ManagerRoomActionsNotifier, void>(
        ManagerRoomActionsNotifier.new);

class ManagerRoomActionsNotifier extends AsyncNotifier<void> {
  late final UpdateRoomStatus usecase;

  final updateRoomStatusUsecaseProvider = Provider<UpdateRoomStatus>((ref) {
    final repo = ref.watch(managerRepositoryProvider);
    return UpdateRoomStatus(repo);
  });

  @override
  void build() {
    usecase = ref.watch(updateRoomStatusUsecaseProvider);
  }

  Future<void> updateRoomStatus(RoomStatus status) async {
    state = const AsyncLoading();

    final result = await usecase.call(status);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) {
        // Refresh the room details after successful update
        ref.invalidate(managerRoomDetailsProvider(status.roomId));
        return const AsyncData(null);
      },
    );
  }
}
