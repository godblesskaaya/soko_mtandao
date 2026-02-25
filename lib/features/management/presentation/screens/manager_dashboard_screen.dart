// features/manager/presentation/screens/manager_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/auth_service.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
import 'package:soko_mtandao/widgets/entity_picker.dart';

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
    try {
      await ref
          .read(managerProfileProvider.future)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(managerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hotel Manager Dashboard"),
        actions: [
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
                child: ListTile(
                  leading: CircleAvatar(
                    child:
                        managerProfile.userMetadata?['avatarUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                  ),
                  title: Text(
                    managerProfile.userMetadata?['fullName'] ?? "Manager",
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(managerProfile.email ?? ""),
                      Text("Phone: ${managerProfile.phone ?? "-"}"),
                      TextButton(
                        onPressed: () =>
                            context.pushNamed("editManagerProfile"),
                        child: const Text("Edit Profile"),
                      ),
                      TextButton(
                        onPressed: () async {
                          await authService.signOut();
                          if (mounted) {
                            context.goNamed("guestHome");
                          }
                        },
                        child: const Text("Logout"),
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
                    "managerUserId":
                        authService.currentUser?.id ?? ""
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

    return await ref.read(
      managerHotelsProvider(managerUserId).future,
    );
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
        final needsParam = {
          'rooms',
          'myHotel',
          'hotelBookings',
          'offerings',
          'managerPayments',
        }.contains(routeName);

        if (needsParam) {
          final selectedHotel =
              await showEntityPicker<ManagerHotel>(
            context: context,
            title: 'Select a hotel',
            fetchItems: _fetchHotelsFromRepo,
            display: (h) => h.name,
          );

          if (selectedHotel == null) return;

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
          color: Theme.of(context).colorScheme.surfaceVariant,
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
}
