import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/constants/app_colors.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/widgets/persona_switcher_button.dart';
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
          const PersonaSwitcherButton(),
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
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.brand),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: set first and last stay nights in Filters for accurate room availability and pricing.',
                  ),
                ),
              ],
            ),
          ),
          const SearchBarWidget(),
          if (state.checkIn != null && state.checkOut != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    'Stay nights: ${formatYmd(state.checkIn!)} to ${formatYmd(state.checkOut!)} (${stayNightsInclusive(state.checkIn!, state.checkOut!)} night(s))',
                  ),
                ),
              ),
            ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Text(
                  '${state.hotels.length} hotel(s) found',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (state.isLoading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Expanded(
            child: HotelListWidget(
              hotels: state.hotels,
              isLoading: state.isLoading,
              hasMore: state.hasMore,
              checkIn: state.checkIn,
              checkOut: state.checkOut,
              onLoadMore: () =>
                  ref.read(hotelSearchProvider.notifier).loadMore(),
            ),
          ),
        ],
      ),
    );
  }
}
