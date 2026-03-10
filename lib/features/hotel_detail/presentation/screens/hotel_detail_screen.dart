import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/widgets/booking_cart_modal.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/widgets/header_carousel.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/widgets/offering_list.dart';

class HotelDetailScreen extends ConsumerStatefulWidget {
  final String hotelId;
  final DateTime? initialFirstNight;
  final DateTime? initialLastNight;

  const HotelDetailScreen({
    super.key,
    required this.hotelId,
    this.initialFirstNight,
    this.initialLastNight,
  });

  @override
  ConsumerState<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends ConsumerState<HotelDetailScreen> {
  DateTime? _firstNight;
  DateTime? _lastNight;

  @override
  void initState() {
    super.initState();
    final firstNight = widget.initialFirstNight;
    final lastNight = widget.initialLastNight;
    if (firstNight != null &&
        lastNight != null &&
        !dateOnly(lastNight).isBefore(dateOnly(firstNight))) {
      _firstNight = dateOnly(firstNight);
      _lastNight = dateOnly(lastNight);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).track(
        'hotel_detail_view',
        params: {'hotel_id': widget.hotelId},
      );
    });
  }

  void _openCartModal() {
    ref.read(analyticsServiceProvider).track(
      'cart_open',
      params: {'hotel_id': widget.hotelId},
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BookingCartModal(),
    );
  }

  void _pickStayNights() async {
    final now = dateOnly(DateTime.now());
    final pickedFirstNight = await showDatePicker(
      context: context,
      initialDate: _firstNight ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedFirstNight == null || !mounted) return;
    final firstNight = dateOnly(pickedFirstNight);

    final shouldPickLastNight = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stay length'),
        content: const Text(
          'Use this date only for a 1-night stay, or pick a last night for multiple nights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Single Night'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pick Last Night'),
          ),
        ],
      ),
    );
    if (shouldPickLastNight == null) return;

    if (!shouldPickLastNight) {
      setState(() {
        _firstNight = firstNight;
        _lastNight = firstNight;
      });
      return;
    }

    final initialLastNight =
        _lastNight != null && !_lastNight!.isBefore(firstNight)
            ? _lastNight!
            : firstNight;
    final pickedLastNight = await showDatePicker(
      context: context,
      initialDate: initialLastNight,
      firstDate: firstNight,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedLastNight == null) return;

    setState(() {
      _firstNight = firstNight;
      _lastNight = dateOnly(pickedLastNight);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hotelAsync = ref.watch(hotelDetailProvider(widget.hotelId));
    final appBarTitle = hotelAsync.maybeWhen(
      data: (hotel) => hotel.name,
      orElse: () => 'Hotel Details',
    );

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: hotelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(userMessageForError(err))),
        data: (hotel) {
          final hasSelectedStay = _firstNight != null && _lastNight != null;
          final stayLabel = hasSelectedStay
              ? '${formatYmd(_firstNight!)} -> ${formatYmd(_lastNight!)} (${stayNightsInclusive(_firstNight!, _lastNight!)} night(s))'
              : 'No stay dates selected';
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderCarousel(hotel: hotel),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text(
                        hotel.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (hotel.address.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18),
                            const SizedBox(width: 6),
                            Expanded(child: Text(hotel.address)),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 18, color: Colors.amber),
                          const SizedBox(width: 6),
                          Text(
                            hotel.rating.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Stay nights',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(stayLabel),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _pickStayNights,
                              child:
                                  Text(hasSelectedStay ? 'Change' : 'Select'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        'About',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(hotel.description),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        'Amenities',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Consumer(builder: (context, ref, _) {
                        final amenities =
                            ref.watch(hotelAmenitiesProvider(hotel.id));
                        return amenities.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          ),
                          error: (err, _) => Text(userMessageForError(err)),
                          data: (a) {
                            if (a.isEmpty) {
                              return const Text('No amenities listed yet.');
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: a
                                  .map(
                                    (am) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(am.name),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        );
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Rooms and Offers',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (!hasSelectedStay)
                            const Text(
                              'Select first and last stay nights to view available room offerings and pricing.',
                            ),
                          if (hasSelectedStay)
                            Consumer(
                              builder: (context, ref, _) {
                                final offeringsAsync =
                                    ref.watch(offeringProvider(hotel.id));
                                return offeringsAsync.when(
                                  loading: () => const Center(
                                      child: CircularProgressIndicator()),
                                  error: (err, _) =>
                                      Text(userMessageForError(err)),
                                  data: (offerings) => OfferingsList(
                                    hotel: hotel,
                                    offerings: offerings,
                                    hotelId: hotel.id,
                                    firstNight: _firstNight!,
                                    lastNight: _lastNight!,
                                  ),
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
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final hasSelectedStay = _firstNight != null && _lastNight != null;
          final cart = ref.watch(bookingCartProvider);
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: cart.isEmpty
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickStayNights,
                        icon: const Icon(Icons.event),
                        label: Text(!hasSelectedStay
                            ? 'Select Stay Dates'
                            : 'Change Stay Dates'),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cart: ${cart.totalItems} room(s)  ${formatTzs(cart.totalPrice)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openCartModal,
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const Text('View Cart'),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
