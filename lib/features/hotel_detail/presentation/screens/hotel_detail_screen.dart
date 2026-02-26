// hotel_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/widgets/booking_cart_modal.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/widgets/header_carousel.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/widgets/offering_list.dart';

class HotelDetailScreen extends ConsumerStatefulWidget {
  final String hotelId;
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;

  const HotelDetailScreen({
    super.key,
    required this.hotelId,
    this.initialCheckIn,
    this.initialCheckOut,
  });

  @override
  ConsumerState<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends ConsumerState<HotelDetailScreen> {
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    final checkIn = widget.initialCheckIn;
    final checkOut = widget.initialCheckOut;
    if (checkIn != null && checkOut != null && checkOut.isAfter(checkIn)) {
      _selectedRange = DateTimeRange(start: checkIn, end: checkOut);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).track(
        'hotel_detail_view',
        params: {'hotel_id': widget.hotelId},
      );
    });
  }

  void _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotelAsync = ref.watch(hotelDetailProvider(widget.hotelId));

    return Scaffold(
      appBar: AppBar(title: const Text("Hotel Details")),
      body: hotelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(userMessageForError(err))),
        data: (hotel) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderCarousel(hotel: hotel),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(hotel.description),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Consumer(builder: (context, ref, _) {
                        final amenities =
                            ref.watch(hotelAmenitiesProvider(hotel.id));
                        return amenities.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (err, _) => Text(userMessageForError(err)),
                          data: (a) => Wrap(
                            spacing: 8,
                            children: a
                                .map((am) => Chip(label: Text(am.name)))
                                .toList(),
                          ),
                        );
                      }),
                    ),

                    // Date range + fetch offerings
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: _pickDateRange,
                            child: Text(_selectedRange == null
                                ? "Select Stay Dates"
                                // display dates in yyyy-mm-dd format
                                : "${_selectedRange!.start.toIso8601String().substring(0, 10)} → ${_selectedRange!.end.toIso8601String().substring(0, 10)}"),
                          ),
                          if (_selectedRange != null)
                            Consumer(
                              builder: (context, ref, _) {
                                final offeringsAsync = ref.watch(
                                  offeringProvider(
                                    hotel.id,
                                  ),
                                );

                                return offeringsAsync.when(
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (err, _) =>
                                      Text(userMessageForError(err)),
                                  data: (offerings) => OfferingsList(
                                      offerings: offerings,
                                      hotelId: hotel.id,
                                      startDate: _selectedRange!.start,
                                      endDate: _selectedRange!.end),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final cart = ref.watch(bookingCartProvider);
          if (cart.isEmpty) return SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () {
              ref.read(analyticsServiceProvider).track(
                'cart_open',
                params: {'hotel_id': widget.hotelId},
              );
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const BookingCartModal(),
              );
            },
            label: Text("Cart (${cart.totalItems})"),
            icon: Icon(Icons.shopping_cart),
          );
        },
      ),
    );
  }
}
