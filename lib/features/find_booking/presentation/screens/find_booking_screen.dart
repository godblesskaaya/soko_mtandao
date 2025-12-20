import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/booking/data/services/local_booking_storage_service.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_details.dart';
import '../riverpod/find_booking_provider.dart';

// 1. RE-USE the provider we defined in the previous step
final localBookingHistoryProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final storage = ref.watch(localBookingStorageProvider);
  return storage.getLocalBookings();
});

class FindBookingScreen extends ConsumerStatefulWidget {
  const FindBookingScreen({super.key});

  @override
  ConsumerState<FindBookingScreen> createState() => _FindBookingScreenState();
}

class _FindBookingScreenState extends ConsumerState<FindBookingScreen> {
  final _controller = TextEditingController();
  String? _searchId; // Use a nullable string to toggle state

  void _performSearch() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        _searchId = _controller.text.trim();
      });
      // Hide keyboard
      FocusScope.of(context).unfocus();
    }
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _searchId = null; // This triggers the switch back to History mode
    });
    // Hide keyboard
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Watch search result ONLY if we are searching
    final searchAsync = _searchId != null
        ? ref.watch(findBookingProvider(_searchId!))
        : null;

    // Watch local history ONLY if we are NOT searching
    final historyAsync = _searchId == null 
        ? ref.watch(localBookingHistoryProvider) 
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_searchId == null ? "My Bookings" : "Search Result"),
        actions: [
          // Optional: A refresh button for the history list
          if (_searchId == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.refresh(localBookingHistoryProvider),
            )
        ],
      ),
      body: Column(
        children: [
          // --- SEARCH BAR SECTION ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: "Search by Booking ID",
                      hintText: "e.g., BK-12345",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      // Show clear button if there is text or an active search
                      suffixIcon: (_controller.text.isNotEmpty || _searchId != null)
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _performSearch,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  child: const Text("Find"),
                ),
              ],
            ),
          ),

          // --- CONTENT SECTION (Switches between History and Search) ---
          Expanded(
            child: _searchId != null
                ? _buildSearchResults(searchAsync!)
                : _buildLocalHistory(historyAsync!),
          ),
        ],
      ),
    );
  }

  // --- Widget for Server Search Results ---
  Widget _buildSearchResults(AsyncValue searchAsync) {
    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
      data: (result) {
        if (!result.found) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  "Booking ID '$_searchId' not found.",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: _clearSearch,
                  child: const Text("Back to My History"),
                )
              ],
            ),
          );
        }
        // If found, show details
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookingDetailsWidget(booking: result.booking!),
        );
      },
    );
  }

  // --- Widget for Local History ---
  Widget _buildLocalHistory(AsyncValue<List<Booking>> historyAsync) {
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error loading history: $e")),
      data: (bookings) {
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("No saved bookings on this device."),
                const SizedBox(height: 8),
                const Text("Bookings you confirm will appear here."),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: bookings.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.bookmark, color: Colors.white),
                ),
                title: Text("Booking #${booking.id}"),
                subtitle: Text("Place: ${booking.bookingCart.bookings.first.hotel.name}\nDate: ${booking.bookingCart.bookings.first.startDate} to ${booking.bookingCart.bookings.first.endDate}"),
                isThreeLine: true,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Pre-fill the search box and trigger search to get latest status
                  _controller.text = booking.id;
                  _performSearch();
                  
                  // OR: If you just want to show the local data without network:
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => 
                  //   BookingDetailsScreen(booking: booking)));
                },
              ),
            );
          },
        );
      },
    );
  }
}