import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/usecases/offerings/delete_offering.dart';
import 'package:soko_mtandao/features/management/domain/usecases/offerings/update_offering.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

typedef OfferingMutationState
    = AsyncValue<Either<Failure, ManagerOffering?>>;

class OfferingMutationNotifier
    extends StateNotifier<OfferingMutationState> {
  final UpdateOffering _update;
  final DeleteOffering _delete;

  OfferingMutationNotifier({
    required UpdateOffering update,
    required DeleteOffering delete,
  })  : _update = update,
        _delete = delete,
        super(const AsyncData(Right(null)));

  Future<void> updateOffering(ManagerOffering offering) async {
    state = const AsyncLoading();
    final result = await _update.call(offering);
    state = AsyncData(result);
  }

  Future<void> deleteOffering(String offeringId) async {
    state = const AsyncLoading();
    final result = await _delete.call(offeringId);

    state = AsyncData(
      result.map((_) => null), // delete returns Unit
    );
  }
}

final offeringMutationProvider = StateNotifierProvider<
    OfferingMutationNotifier,
    OfferingMutationState>((ref) {
  return OfferingMutationNotifier(
    update: ref.watch(updateOfferingUseCaseProvider),
    delete: ref.watch(deleteOfferingUseCaseProvider),
  );
});


final updateOfferingUseCaseProvider = Provider<UpdateOffering>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return UpdateOffering(repo);
});

final deleteOfferingUseCaseProvider = Provider<DeleteOffering>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return DeleteOffering(repo);
});

