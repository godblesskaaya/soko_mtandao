// features/manager/presentation/screens/manager_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/auth_service.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';
import 'package:soko_mtandao/widgets/entity_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerDashboardScreen extends ConsumerStatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  ConsumerState<ManagerDashboardScreen> createState() =>
      _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState
    extends ConsumerState<ManagerDashboardScreen> {
  final AuthService authService = AuthService();

  Future<void> _refresh() async {
    ref.invalidate(managerProfileProvider);
    final selectedHotelId = ref.read(selectedManagerHotelIdProvider);
    if (selectedHotelId != null && selectedHotelId.isNotEmpty) {
      ref.invalidate(hotelDetailProvider(selectedHotelId));
    }
    try {
      await ref
          .read(managerProfileProvider.future)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(managerProfileProvider);
    final selectedHotelId = ref.watch(selectedManagerHotelIdProvider);
    final activeHotelAsync = selectedHotelId == null || selectedHotelId.isEmpty
        ? null
        : ref.watch(hotelDetailProvider(selectedHotelId));
    final activeHotelLabel = activeHotelAsync == null
        ? 'Not selected'
        : activeHotelAsync.maybeWhen(
            data: (hotel) => hotel.name,
            loading: () => 'Loading active hotel...',
            orElse: () => 'Active hotel unavailable',
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hotel Manager Dashboard"),
        actions: [
          IconButton(
            tooltip: 'Switch active hotel',
            icon: const Icon(Icons.domain_outlined),
            onPressed: () async {
              final selectedHotel = await showEntityPicker<ManagerHotel>(
                context: context,
                title: 'Set Active Hotel',
                fetchItems: _fetchHotelsFromRepo,
                display: (h) => h.name,
              );
              if (selectedHotel == null) return;
              ref.read(selectedManagerHotelIdProvider.notifier).state =
                  selectedHotel.id;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Active hotel: ${selectedHotel.name}')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.pushNamed("notifications"),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.pushNamed("settings"),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            /// 👤 Manager Profile
            profileAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Card(
                child: ListTile(
                  title: const Text("Error loading profile"),
                  subtitle: Text(userMessageForError(err)),
                  trailing: const Text("Pull to retry"),
                ),
              ),
              data: (managerProfile) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            _resolveDisplayName(managerProfile)
                                .substring(0, 1)
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(_resolveDisplayName(managerProfile)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(managerProfile.email ?? ""),
                            Text(
                              "Phone: ${managerProfile.phone ?? managerProfile.userMetadata?['phone'] ?? "-"}",
                            ),
                            Text(
                              "Role: ${_resolveManagerRole(managerProfile.userMetadata)}",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Active hotel: $activeHotelLabel'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  context.pushNamed("editManagerProfile"),
                              child: const Text("Edit Profile"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await authService.signOut();
                                if (!context.mounted) return;
                                context.goNamed("guestHome");
                              },
                              child: const Text("Logout"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// ⚡ Quick Actions
            Text(
              "Quick Actions",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  "Hotels",
                  Icons.book_online,
                  context,
                  "hotelList",
                  pathParameters: {
                    "managerUserId": authService.currentUser?.id ?? ""
                  },
                ),
                _buildActionButton(
                  "Rooms",
                  Icons.meeting_room,
                  context,
                  "rooms",
                ),
                _buildActionButton(
                  "Offerings",
                  Icons.people,
                  context,
                  "offerings",
                ),
                _buildActionButton(
                  "Bookings",
                  Icons.bar_chart,
                  context,
                  "hotelBookings",
                ),
                _buildActionButton(
                  "Payments",
                  Icons.payments,
                  context,
                  "managerPayments",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<ManagerHotel>> _fetchHotelsFromRepo() async {
    final managerUserId = authService.currentUser?.id;
    if (managerUserId == null || managerUserId.isEmpty) return [];

    return ref.read(managerHotelsProvider(managerUserId).future);
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    BuildContext context,
    String routeName, {
    Map<String, String>? pathParameters,
  }) {
    return GestureDetector(
      onTap: () async {
        ref.read(analyticsServiceProvider).track(
            'manager_dashboard_action_click',
            params: {'route': routeName});
        final needsParam = {
          'rooms',
          'myHotel',
          'hotelBookings',
          'offerings',
          'managerPayments',
        }.contains(routeName);

        if (needsParam) {
          ManagerHotel? selectedHotel;
          final selectedHotelId = ref.read(selectedManagerHotelIdProvider);
          if (selectedHotelId != null && selectedHotelId.isNotEmpty) {
            final hotels = await _fetchHotelsFromRepo();
            if (!context.mounted) return;
            final existing = hotels.where((h) => h.id == selectedHotelId);
            if (existing.isNotEmpty) selectedHotel = existing.first;
          }

          if (!context.mounted) return;
          selectedHotel ??= await showEntityPicker<ManagerHotel>(
            context: context,
            title: 'Select a hotel',
            fetchItems: _fetchHotelsFromRepo,
            display: (h) => h.name,
          );

          if (selectedHotel == null) return;
          ref.read(selectedManagerHotelIdProvider.notifier).state =
              selectedHotel.id;

          if (!context.mounted) return;
          context.pushNamed(
            routeName,
            pathParameters: {
              'hotelId': selectedHotel.id,
              ...?pathParameters,
            },
          );
          return;
        }

        context.pushNamed(
          routeName,
          pathParameters: pathParameters ?? {},
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _resolveDisplayName(User managerProfile) {
    final metadata = managerProfile.userMetadata;
    final fullName = (metadata?['fullName'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
    final firstName = (metadata?['firstName'] ?? '').toString().trim();
    final lastName = (metadata?['lastName'] ?? '').toString().trim();
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? 'Manager' : combined;
  }

  String _resolveManagerRole(Map<String, dynamic>? metadata) {
    final title = (metadata?['managerTitle'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    final role = (metadata?['role'] ?? '').toString().trim();
    if (role.isNotEmpty) {
      return role
          .split('_')
          .map((part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
    }
    return 'Hotel Manager';
  }
}
