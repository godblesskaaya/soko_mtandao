import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_room_item.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/widgets/hotel_policy_section.dart';

class BookingHotelSection extends ConsumerWidget {
  final BookingInput booking;

  const BookingHotelSection({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = stayNightsInclusive(booking.startDate, booking.endDate);
    final hotelAsync = ref.watch(hotelDetailProvider(booking.hotel.id));
    final effectiveHotel = hotelAsync.maybeWhen(
      data: (hotel) => hotel,
      orElse: () => booking.hotel,
    );
    final hasPolicies = effectiveHotel.checkInFrom != null ||
        effectiveHotel.checkInUntil != null ||
        effectiveHotel.checkOutUntil != null ||
        effectiveHotel.stayRules.isNotEmpty ||
        effectiveHotel.checkInRequirements.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          booking.hotel.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          '${formatYmd(booking.startDate)} -> ${formatYmd(booking.endDate)}  ($nights nights)',
        ),
        const SizedBox(height: 8),
        ...booking.items
            .map((item) => BookingRoomItem(item: item, nights: nights)),
        if (hasPolicies) ...[
          const SizedBox(height: 12),
          HotelPolicySection(
            hotel: effectiveHotel,
            title: 'Before you pay',
            compact: true,
          ),
        ],
        const Divider(height: 32),
      ],
    );
  }
}
