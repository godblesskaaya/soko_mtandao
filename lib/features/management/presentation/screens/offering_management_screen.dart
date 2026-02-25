import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_offering_providers.dart';

class OfferingListScreen extends ConsumerStatefulWidget {
  final String hotelId;
  const OfferingListScreen({super.key, required this.hotelId});

  @override
  ConsumerState<OfferingListScreen> createState() => _OfferingListScreenState();
}

class _OfferingListScreenState extends ConsumerState<OfferingListScreen> {
  static const int _pageSize = 20;
  int _page = 1;
  String _sortBy = 'title';
  bool _sortAsc = true;
  bool? _isAvailable;

  ManagerOfferingListQuery get _query => ManagerOfferingListQuery(
        hotelId: widget.hotelId,
        page: _page,
        limit: _pageSize,
        sortBy: _sortBy,
        sortAscending: _sortAsc,
        isAvailable: _isAvailable,
      );

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(offeringsPageProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Offerings"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() {
              _sortBy = value;
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'title', child: Text('Sort: Title')),
              PopupMenuItem(value: 'price', child: Text('Sort: Price')),
              PopupMenuItem(value: 'max_guests', child: Text('Sort: Max Guests')),
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
              _isAvailable = value;
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem<bool?>(value: null, child: Text('Filter: All')),
              PopupMenuItem<bool?>(value: true, child: Text('Filter: Available')),
              PopupMenuItem<bool?>(value: false, child: Text('Filter: Unavailable')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(offeringsPageProvider(_query));
          try {
            await ref.read(offeringsPageProvider(_query).future).timeout(const Duration(seconds: 8));
          } catch (_) {}
        },
        child: offeringsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())],
          ),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text(userMessageForError(err))),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(offeringsPageProvider(_query)),
                  child: const Text("Retry"),
                ),
              ),
            ],
          ),
          data: (offerings) {
            if (offerings.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  Center(child: Text(_page > 1 ? "No more offerings." : "No offerings yet.")),
                ],
              );
            }

            final hasNext = offerings.length == _pageSize;
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: offerings.length + 1,
              itemBuilder: (_, i) {
                if (i == offerings.length) {
                  return _PaginationControls(
                    page: _page,
                    hasNext: hasNext,
                    onPrev: _page > 1 ? () => setState(() => _page -= 1) : null,
                    onNext: hasNext ? () => setState(() => _page += 1) : null,
                  );
                }

                final off = offerings[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(off.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(off.description),
                        Text("TZS ${off.basePrice}/night"),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: off.id == null
                          ? null
                          : () => context.pushNamed(
                                "editOffering",
                                pathParameters: {"offeringId": off.id!, "hotelId": widget.hotelId},
                              ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed("addOfferings", pathParameters: {"hotelId": widget.hotelId}),
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
          OutlinedButton(onPressed: hasNext ? onNext : null, child: const Text("Next")),
        ],
      ),
    );
  }
}
