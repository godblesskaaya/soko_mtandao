// features/manager/presentation/screens/hotel_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';

class ManagerHotelDetailScreen extends ConsumerStatefulWidget {
  final String hotelId;
  const ManagerHotelDetailScreen({super.key, required this.hotelId});

  @override
  ConsumerState<ManagerHotelDetailScreen> createState() =>
      _ManagerHotelDetailScreenState();
}

class _ManagerHotelDetailScreenState
    extends ConsumerState<ManagerHotelDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedManagerHotelIdProvider.notifier).state = widget.hotelId;
    });
  }

  @override
  void didUpdateWidget(covariant ManagerHotelDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotelId != widget.hotelId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedManagerHotelIdProvider.notifier).state =
            widget.hotelId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotelAsync = ref.watch(hotelDetailProvider(widget.hotelId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hotel Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.pushNamed(
                "editHotel",
                pathParameters: {"hotelId": widget.hotelId},
              );

              // Refresh after edit
              ref.invalidate(hotelDetailProvider(widget.hotelId));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(hotelDetailProvider(widget.hotelId));
          try {
            await ref
                .read(hotelDetailProvider(widget.hotelId).future)
                .timeout(const Duration(seconds: 8));
          } catch (_) {}
        },
        child: hotelAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text(userMessageForError(err))),
              const SizedBox(height: 8),
              const Center(child: Text("Pull down to retry")),
            ],
          ),
          data: (hotel) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              /// 🖼️ Cover Image
              if (hotel.images != null && hotel.images!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    hotel.images!.first,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 16),

              /// 🏨 Name & Location
              Text(
                hotel.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  const Icon(Icons.location_on, size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(hotel.address ?? "No address"),
                  ),
                ],
              ),

              Row(
                children: [
                  const Icon(Icons.map, size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "${hotel.lat} ${hotel.lng}",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (hotel.email != null)
                Row(
                  children: [
                    const Icon(Icons.email, size: 18),
                    const SizedBox(width: 4),
                    Text(hotel.email!),
                  ],
                ),

              if (hotel.phoneNumber != null)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 18),
                    const SizedBox(width: 4),
                    Text(hotel.phoneNumber!),
                  ],
                ),

              const Divider(height: 32),

              /// 📝 Description
              if (hotel.description != null)
                Text(
                  hotel.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

              const SizedBox(height: 20),

              /// 🛎️ Amenities
              if (hotel.amenities.isNotEmpty) ...[
                Text(
                  "Amenities",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: hotel.amenities
                      .map(
                        (a) => Chip(
                          avatar: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: Text(a.name),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              /// ⚡ Manage Actions
              Text(
                "Manage",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildActionButton("Offerings", Icons.add_box, () {
                    context.pushNamed(
                      "offerings",
                      pathParameters: {"hotelId": widget.hotelId},
                    );
                  }),
                  _buildActionButton("Rooms", Icons.add_home_work, () {
                    context.pushNamed(
                      "rooms",
                      pathParameters: {"hotelId": widget.hotelId},
                    );
                  }),
                  _buildActionButton("View Bookings", Icons.book_online, () {
                    context.pushNamed(
                      "hotelBookings",
                      pathParameters: {"hotelId": widget.hotelId},
                    );
                  }),
                  _buildActionButton("Payments", Icons.payments, () {
                    context.pushNamed(
                      "managerPayments",
                      pathParameters: {"hotelId": widget.hotelId},
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
