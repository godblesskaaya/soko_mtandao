import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/domain/usecases/bookings/get_bookings.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_booking_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/selected_manager_hotel_provider.dart';
import 'package:soko_mtandao/features/management/presentation/widgets/active_hotel_context_bar.dart';

class BookingListScreen extends ConsumerStatefulWidget {
  final String hotelId;
  const BookingListScreen({super.key, required this.hotelId});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen> {
  static const int _pageSize = 20;
  int _page = 1;
  String _sortBy = 'start_date';
  bool _sortAsc = false;

  void _syncActiveHotelSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedHotelId = ref.read(selectedManagerHotelIdProvider);
      if (selectedHotelId == widget.hotelId) return;
      ref.read(selectedManagerHotelIdProvider.notifier).state = widget.hotelId;
    });
  }

  BookingQueryParams get _query => BookingQueryParams(
        hotelId: widget.hotelId,
        page: _page,
        limit: _pageSize,
        sortBy: _sortBy,
        sortAscending: _sortAsc,
      );

  @override
  void initState() {
    super.initState();
    _syncActiveHotelSelection();
  }

  @override
  void didUpdateWidget(covariant BookingListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotelId != widget.hotelId) {
      _syncActiveHotelSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingDataAsync = ref.watch(bookingListCombinedProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bookings"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() {
              _sortBy = value;
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'start_date', child: Text('Sort: Start Date')),
              PopupMenuItem(value: 'end_date', child: Text('Sort: End Date')),
              PopupMenuItem(
                  value: 'created_at', child: Text('Sort: Created At')),
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
        ],
      ),
      body: Column(
        children: [
          ActiveHotelContextBar(
            activeHotelId: widget.hotelId,
            routeName: 'hotelBookings',
            subtitle: 'You are viewing bookings for this hotel.',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(bookingListCombinedProvider(_query));
                try {
                  await ref
                      .read(bookingListCombinedProvider(_query).future)
                      .timeout(const Duration(seconds: 8));
                } catch (_) {}
              },
              child: bookingDataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 200),
                    Center(child: Text(userMessageForError(err))),
                    const SizedBox(height: 12),
                    const Center(child: Text("Pull down to retry")),
                  ],
                ),
                data: (bookingList) {
                  if (bookingList.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 200),
                        Center(
                            child: Text(_page > 1
                                ? "No more bookings."
                                : "No bookings yet.")),
                        if (_page > 1)
                          Center(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _page -= 1),
                              child: const Text("Previous Page"),
                            ),
                          ),
                      ],
                    );
                  }

                  final hasNext = bookingList.length == _pageSize;
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: bookingList.length + 1,
                    itemBuilder: (context, i) {
                      if (i == bookingList.length) {
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

                      final data = bookingList[i];
                      return Card(
                        child: ListTile(
                          title: Text(data.detail.customerName ?? "Anonymous"),
                          subtitle: Text(
                            "Room: ${data.room.roomNumber} -> "
                            "${data.booking.startDate?.toIso8601String().substring(0, 10)}   "
                            "${data.booking.endDate?.toIso8601String().substring(0, 10)}",
                          ),
                          trailing: Text(data.detail.status ?? "unknown"),
                          onTap: () async {
                            await context.pushNamed(
                              "managerBookingDetail",
                              pathParameters: {'bookingId': data.detail.id},
                            );
                            ref.invalidate(bookingListCombinedProvider(_query));
                          },
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
