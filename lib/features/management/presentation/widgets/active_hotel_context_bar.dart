import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';
import 'package:soko_mtandao/widgets/entity_picker.dart';

class ActiveHotelContextBar extends ConsumerWidget {
  final String activeHotelId;
  final String routeName;
  final String? subtitle;
  final Map<String, String> extraPathParameters;

  const ActiveHotelContextBar({
    super.key,
    required this.activeHotelId,
    required this.routeName,
    this.subtitle,
    this.extraPathParameters = const <String, String>{},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerUserId = ref.watch(authServiceProvider).currentUser?.id;
    final hotelsAsync = managerUserId == null || managerUserId.isEmpty
        ? const AsyncData<List<ManagerHotel>>(<ManagerHotel>[])
        : ref.watch(managerHotelsProvider(managerUserId));

    final activeHotelName = hotelsAsync.maybeWhen(
      data: (hotels) {
        for (final hotel in hotels) {
          if (hotel.id == activeHotelId) {
            return hotel.name;
          }
        }
        return null;
      },
      orElse: () => null,
    );

    final effectiveSubtitle = subtitle ?? 'Changes apply to this hotel only.';
    final displayName = activeHotelName ?? 'Hotel ID: $activeHotelId';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.business_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    effectiveSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: managerUserId == null || managerUserId.isEmpty
                  ? null
                  : () async {
                      final selectedHotel =
                          await showEntityPicker<ManagerHotel>(
                        context: context,
                        title: 'Switch Active Hotel',
                        fetchItems: () => ref
                            .read(managerHotelsProvider(managerUserId).future),
                        display: (hotel) => hotel.name,
                      );

                      if (selectedHotel == null) return;

                      ref.read(selectedManagerHotelIdProvider.notifier).state =
                          selectedHotel.id;
                      ref.read(analyticsServiceProvider).track(
                        'manager_active_hotel_switched',
                        params: {
                          'route': routeName,
                          'hotelId': selectedHotel.id,
                        },
                      );

                      if (!context.mounted) return;
                      if (selectedHotel.id == activeHotelId) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Already managing ${selectedHotel.name}.'),
                          ),
                        );
                        return;
                      }

                      context.goNamed(
                        routeName,
                        pathParameters: {
                          'hotelId': selectedHotel.id,
                          ...extraPathParameters,
                        },
                      );
                    },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch'),
            ),
          ],
        ),
      ),
    );
  }
}
