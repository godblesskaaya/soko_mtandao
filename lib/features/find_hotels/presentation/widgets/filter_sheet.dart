import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/riverpod/hotel_search_provider.dart';

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late TextEditingController regionController;
  late TextEditingController cityController;
  late TextEditingController minPriceController;
  late TextEditingController maxPriceController;
  late TextEditingController guestsController;
  DateTime? _checkIn;
  DateTime? _checkOut;

  @override
  void initState() {
    super.initState();
    final state = ref.read(hotelSearchProvider);

    regionController = TextEditingController(text: state.region);
    cityController = TextEditingController(text: state.city);
    minPriceController =
        TextEditingController(text: state.minPrice?.toString() ?? "");
    maxPriceController =
        TextEditingController(text: state.maxPrice?.toString() ?? "");
    guestsController =
        TextEditingController(text: state.guests?.toString() ?? "");
    _checkIn = state.checkIn;
    _checkOut = state.checkOut;
  }

  @override
  void dispose() {
    regionController.dispose();
    cityController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    guestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(hotelSearchProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: regionController,
            decoration: const InputDecoration(labelText: "Region"),
          ),
          TextField(
            controller: cityController,
            decoration: const InputDecoration(labelText: "City"),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minPriceController,
                  decoration: const InputDecoration(labelText: "Min Price"),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: maxPriceController,
                  decoration: const InputDecoration(labelText: "Max Price"),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          TextField(
            controller: guestsController,
            decoration: const InputDecoration(labelText: "Guests"),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _checkIn == null
                  ? 'Check-in date'
                  : 'Check-in: ${_checkIn!.toIso8601String().substring(0, 10)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _checkIn ?? now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked == null) return;
              setState(() {
                _checkIn = picked;
                if (_checkOut != null && !_checkOut!.isAfter(_checkIn!)) {
                  _checkOut = null;
                }
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _checkOut == null
                  ? 'Check-out date'
                  : 'Check-out: ${_checkOut!.toIso8601String().substring(0, 10)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final now = DateTime.now();
              final min = _checkIn ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: _checkOut ?? min.add(const Duration(days: 1)),
                firstDate: min.add(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked == null) return;
              setState(() => _checkOut = picked);
            },
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              final notifier = ref.read(hotelSearchProvider.notifier);

              // Reset UI text fields as well
              regionController.clear();
              cityController.clear();
              minPriceController.clear();
              maxPriceController.clear();
              guestsController.clear();
              setState(() {
                _checkIn = null;
                _checkOut = null;
              });

              notifier.clearFilters();
              Navigator.pop(context);
            },
            child: const Text(
              "Clear Filters",
              style: TextStyle(color: Color.fromARGB(129, 232, 99, 90)),
            ),
          ),
          ElevatedButton(
            child: const Text("Apply Filters"),
            onPressed: () {
              notifier.updateRegion(regionController.text);
              notifier.updateCity(cityController.text);

              notifier.updateMinPrice(
                minPriceController.text,
              );
              notifier.updateMaxPrice(
                maxPriceController.text,
              );

              notifier.updateGuests(guestsController.text);
              notifier.updateDateRange(_checkIn, _checkOut);

              notifier.applyFilters();
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }
}
