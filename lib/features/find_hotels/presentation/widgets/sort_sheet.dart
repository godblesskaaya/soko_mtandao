import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/riverpod/hotel_search_notifier.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/riverpod/hotel_search_provider.dart';

class SortSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(hotelSearchProvider).sortOption;

    final notifier = ref.read(hotelSearchProvider.notifier);

    return ListView(
      shrinkWrap: true,
      children: [
        _option("Relevance", "relevance", selected, notifier),
        _option("Price: Low → High", "price_asc", selected, notifier),
        _option("Price: High → Low", "price_desc", selected, notifier),
        _option("Rating: Low → High", "rating_asc", selected, notifier),
        _option("Rating: High → Low", "rating_desc", selected, notifier),
        _option("Rooms Available: High → Low", "rooms_desc", selected, notifier),
        _option("Name: A → Z", "name_asc", selected, notifier),
        _option("Name: Z → A", "name_desc", selected, notifier),
      ],
    );
  }

  Widget _option(String title, String value, String selected,
      HotelSearchNotifier notifier) {
    return ListTile(
      title: Text(title),
      trailing: value == selected ? const Icon(Icons.check) : null,
      onTap: () {
        notifier.updateSort(value);
      },
    );
  }
}
