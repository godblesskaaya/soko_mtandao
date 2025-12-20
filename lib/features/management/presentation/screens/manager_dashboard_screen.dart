// features/manager/presentation/screens/manager_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/services/auth_service.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
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
  Future<void> _refresh() async {
    // refresh both profile + bookings
    ref.invalidate(managerProfileProvider);
    // ref.invalidate(bookingListProvider);
  }

  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(managerProfileProvider);
    // final bookingsAsync = ref.watch(bookingListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 Manager Profile
              profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Card(
                  child: ListTile(
                    title: const Text("Error loading profile"),
                    subtitle: Text(err.toString()),
                  ),
                ),
                data: (managerProfile) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        // backgroundImage: managerProfile.userMetadata != null
                        //     ? NetworkImage(managerProfile.userMetadata!['avatarUrl'] as String)
                        //     : null,
                        child: managerProfile.userMetadata!['avatarUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(managerProfile.userMetadata!['fullName'] ?? "Manager"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(managerProfile.email ?? ""),
                          Text("Phone: ${managerProfile.phone ?? "-"}"),
                          // button to edit profile
                          TextButton(
                            onPressed: () =>
                                context.pushNamed("editManagerProfile"),
                            child: const Text("Edit Profile"),
                          ),
                          // button to logout
                          TextButton(
                            onPressed: () async {
                              await authService.signOut();
                              if (mounted) context.goNamed("guestHome");
                            },
                            child: const Text("Logout"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ⚡ Quick Actions
              Text("Quick Actions",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildActionButton(
                      "Hotels", Icons.book_online, context, "hotelList", pathParameters: {"managerUserId": authService.currentUser?.id ?? ""}),
                  _buildActionButton(
                      "Rooms", Icons.meeting_room, context, "rooms"),
                  _buildActionButton(
                      "Offerings", Icons.people, context, "offerings", pathParameters: {}),
                  _buildActionButton(
                      "Bookings", Icons.bar_chart, context, "hotelBookings"),
                  _buildActionButton(
                      "Payments", Icons.payments, context, "managerPayments"),
                ],
              ),

              const SizedBox(height: 30),

              // // 📅 Upcoming Bookings
              // Text("Upcoming Check-ins",
              //     style: Theme.of(context).textTheme.titleMedium),
              // const SizedBox(height: 10),
              // bookingsAsync.when(
              //   loading: () => const Center(child: CircularProgressIndicator()),
              //   error: (err, _) => Text("Error loading bookings: $err"),
              //   data: (bookings) {
              //     if (bookings.isEmpty) {
              //       return const Text("No upcoming check-ins.");
              //     }

              //     final limited = bookings.take(5).toList();
              //     return Column(
              //       children: [
              //         ...limited.map((b) => Card(
              //               child: ListTile(
              //                 leading: const Icon(Icons.person),
              //                 title: Text(b.guestName),
              //                 subtitle: Text(
              //                     "Room ${b.roomNumber} • ${b.checkInDate.toLocal()}"),
              //                 trailing:
              //                     const Icon(Icons.arrow_forward_ios, size: 16),
              //                 onTap: () {
              //                   context.pushNamed("bookingDetail",
              //                       pathParameters: {"bookingId": b.id});
              //                 },
              //               ),
              //             )),
              //         if (bookings.length > 5)
              //           TextButton(
              //             onPressed: () =>
              //                 context.pushNamed("managerBookings"),
              //             child: const Text("View all"),
              //           )
              //       ],
              //     );
              //   },
              // ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<List<ManagerHotel>> _fetchHotelsFromRepo(WidgetRef ref) async {
    final managerUserId = authService.currentUser?.id;
    if (managerUserId == null || managerUserId.isEmpty) return [];
  // Use ref to access repo/provider
  final hotelsAsync = ref.watch(managerHotelsProvider(managerUserId));

  return hotelsAsync.when(
    data: (hotels) => hotels,
    loading: () => [],
    error: (err, _) => [],
  );
}

  Widget _buildActionButton(
      String label, IconData icon, BuildContext context, String routeName, {Map<String, String>? pathParameters}) {
    return GestureDetector(
      onTap: () async {
        final needsParam = {'rooms', 'myHotel', 'hotelBookings', 'offerings', 'managerPayments'}.contains(routeName);

        if (needsParam) {
          final selectedHotel = await showEntityPicker<ManagerHotel>(
            context: context,
            title: 'Select a hotel',
            fetchItems: () => _fetchHotelsFromRepo(ref),
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
        }
         context.pushNamed(routeName, pathParameters: pathParameters ?? {});
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
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
