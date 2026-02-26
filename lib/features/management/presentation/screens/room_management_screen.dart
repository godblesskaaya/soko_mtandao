import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_room_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';
import 'package:soko_mtandao/features/management/presentation/widgets/active_hotel_context_bar.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  final String hotelId;
  const RoomListScreen({super.key, required this.hotelId});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  static const int _pageSize = 20;
  int _page = 1;
  String _sortBy = 'room_number';
  bool _sortAsc = true;
  bool? _isActive;

  void _syncActiveHotelSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedHotelId = ref.read(selectedManagerHotelIdProvider);
      if (selectedHotelId == widget.hotelId) return;
      ref.read(selectedManagerHotelIdProvider.notifier).state = widget.hotelId;
    });
  }

  ManagerRoomListQuery get _query => ManagerRoomListQuery(
        hotelId: widget.hotelId,
        page: _page,
        limit: _pageSize,
        sortBy: _sortBy,
        sortAscending: _sortAsc,
        isActive: _isActive,
      );

  @override
  void initState() {
    super.initState();
    _syncActiveHotelSelection();
  }

  @override
  void didUpdateWidget(covariant RoomListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotelId != widget.hotelId) {
      _syncActiveHotelSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsPageProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rooms"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() {
              _sortBy = value;
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'room_number', child: Text('Sort: Room Number')),
              PopupMenuItem(value: 'capacity', child: Text('Sort: Capacity')),
              PopupMenuItem(
                  value: 'is_active', child: Text('Sort: Active First')),
            ],
          ),
          IconButton(
            tooltip: _sortAsc ? 'Ascending' : 'Descending',
            onPressed: () => setState(() {
              _sortAsc = !_sortAsc;
              _page = 1;
            }),
            icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
          ),
          PopupMenuButton<bool?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() {
              _isActive = value;
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem<bool?>(value: null, child: Text('Filter: All')),
              PopupMenuItem<bool?>(value: true, child: Text('Filter: Active')),
              PopupMenuItem<bool?>(
                  value: false, child: Text('Filter: Inactive')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ActiveHotelContextBar(
            activeHotelId: widget.hotelId,
            routeName: 'rooms',
            subtitle: 'You are managing rooms for this hotel.',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(roomsPageProvider(_query));
                try {
                  await ref
                      .read(roomsPageProvider(_query).future)
                      .timeout(const Duration(seconds: 8));
                } catch (_) {}
              },
              child: roomsAsync.when(
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: CircularProgressIndicator())
                  ],
                ),
                error: (err, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 200),
                    Center(
                      child: Column(
                        children: [
                          Text(userMessageForError(err)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(roomsPageProvider(_query)),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 200),
                        Center(
                            child: Text(_page > 1
                                ? "No more rooms."
                                : "No rooms yet.")),
                      ],
                    );
                  }

                  final hasNext = rooms.length == _pageSize;
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rooms.length + 1,
                    itemBuilder: (_, i) {
                      if (i == rooms.length) {
                        return _PaginationControls(
                          page: _page,
                          hasNext: hasNext,
                          onPrev: _page > 1
                              ? () => setState(() => _page -= 1)
                              : null,
                          onNext:
                              hasNext ? () => setState(() => _page += 1) : null,
                        );
                      }

                      final room = rooms[i];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text('Room Number: ${room.roomNumber}'),
                          subtitle: Text("Capacity: ${room.capacity} people"),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => context.pushNamed(
                              "editRoom",
                              pathParameters: {
                                "roomId": room.id,
                                "hotelId": widget.hotelId
                              },
                            ),
                          ),
                          onTap: () => context.pushNamed(
                            "roomDetails",
                            pathParameters: {"roomId": room.id},
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context
            .pushNamed("addRooms", pathParameters: {"hotelId": widget.hotelId}),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int page;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationControls({
    required this.page,
    required this.hasNext,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(onPressed: onPrev, child: const Text("Previous")),
          Text("Page $page"),
          OutlinedButton(
              onPressed: hasNext ? onNext : null, child: const Text("Next")),
        ],
      ),
    );
  }
}
