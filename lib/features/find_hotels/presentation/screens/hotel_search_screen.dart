import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/widgets/filter_sheet.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/widgets/hotel_list.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/widgets/search_bar.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/widgets/sort_sheet.dart';
import '../riverpod/hotel_search_provider.dart';

class HotelSearchScreen extends ConsumerWidget {
  const HotelSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hotelSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Hotels"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => const SortSheet(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FilterSheet(),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          SearchBarWidget(),
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.red.shade50,
              child: Text(
                userMessageForError(state.error!),
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),

          Expanded(
            child: HotelListWidget(
              hotels: state.hotels,
              isLoading: state.isLoading,
              hasMore: state.hasMore,
              onLoadMore: () =>
                  ref.read(hotelSearchProvider.notifier).loadMore(),
            ),
          ),
        ],
      ),
    );
  }
}
