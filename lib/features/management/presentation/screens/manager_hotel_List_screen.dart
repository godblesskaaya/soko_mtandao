import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';

class ManagerHotelListScreen extends ConsumerStatefulWidget {
  final String managerUserId;
  const ManagerHotelListScreen({
    super.key,
    required this.managerUserId,
  });

  @override
  ConsumerState<ManagerHotelListScreen> createState() =>
      _ManagerHotelListScreenState();
}

class _ManagerHotelListScreenState
    extends ConsumerState<ManagerHotelListScreen> {
  static const int _pageSize = 20;
  int _page = 1;
  String _sortBy = 'name';
  bool _sortAsc = true;

  ManagerHotelListQuery get _query => ManagerHotelListQuery(
        managerUserId: widget.managerUserId,
        page: _page,
        limit: _pageSize,
        sortBy: _sortBy,
        sortAscending: _sortAsc,
      );

  @override
  Widget build(BuildContext context) {
    final hotelsAsync = ref.watch(managerHotelsPageProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Hotels"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() {
              _sortBy = value;
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'name', child: Text('Sort: Name')),
              PopupMenuItem(value: 'rating', child: Text('Sort: Rating')),
              PopupMenuItem(value: 'city', child: Text('Sort: City')),
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(managerHotelsPageProvider(_query));
          try {
            await ref
                .read(managerHotelsPageProvider(_query).future)
                .timeout(const Duration(seconds: 8));
          } catch (_) {}
        },
        child: hotelsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text(userMessageForError(err))),
              const SizedBox(height: 8),
              const Center(child: Text("Pull down to retry")),
            ],
          ),
          data: (hotels) {
            if (hotels.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  Center(
                      child: Text(
                          _page > 1 ? "No more hotels." : "No hotels found.")),
                  const SizedBox(height: 12),
                  if (_page > 1)
                    Center(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _page -= 1),
                        child: const Text("Previous Page"),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.pushNamed("addHotel");
                        ref.invalidate(managerHotelsPageProvider(_query));
                      },
                      child: const Text("Add Hotel"),
                    ),
                  ),
                ],
              );
            }

            final hasNext = hotels.length == _pageSize;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: hotels.length + 1,
              itemBuilder: (_, index) {
                if (index == hotels.length) {
                  return _PaginationControls(
                    page: _page,
                    hasNext: hasNext,
                    onPrev: _page > 1 ? () => setState(() => _page -= 1) : null,
                    onNext: hasNext ? () => setState(() => _page += 1) : null,
                  );
                }

                final h = hotels[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: h.images.isNotEmpty
                        ? Image.network(h.images.first,
                            width: 60, fit: BoxFit.cover)
                        : const Icon(Icons.hotel, size: 40),
                    title: Text(h.name),
                    subtitle: Text(h.address),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        await context.pushNamed("editHotel",
                            pathParameters: {"hotelId": h.id});
                        ref.invalidate(managerHotelsPageProvider(_query));
                      },
                    ),
                    onTap: () async {
                      await context.pushNamed("hotelPage",
                          pathParameters: {"hotelId": h.id});
                      ref.invalidate(managerHotelsPageProvider(_query));
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.pushNamed("addHotel");
          ref.invalidate(managerHotelsPageProvider(_query));
        },
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
