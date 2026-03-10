import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/hotel.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/offering.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';
import 'package:uuid/uuid.dart';

class OfferingsList extends ConsumerWidget {
  final Hotel hotel;
  final List<Offering> offerings;
  final String hotelId;
  final DateTime firstNight;
  final DateTime lastNight;
  const OfferingsList({
    super.key,
    required this.hotel,
    required this.offerings,
    required this.hotelId,
    required this.firstNight,
    required this.lastNight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = stayNightsInclusive(firstNight, lastNight);
    if (offerings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text("No offerings for selected dates."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: offerings.map((off) {
        final coverImage = off.images.isNotEmpty
            ? off.images.first
            : (hotel.images.isNotEmpty ? hotel.images.first : null);
        final stayPrice = off.pricePerNight * nights;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coverImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      coverImage,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 30),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.photo_library_outlined, size: 30),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  off.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (off.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    off.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.group_outlined, size: 16),
                      label: Text('Up to ${off.maxGuests} guests'),
                    ),
                    ...off.amenities.take(3).map(
                          (amenity) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(amenity.name),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatTzs(off.pricePerNight)} / night',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '$nights night total: ${formatTzs(stayPrice)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showRoomModal(context, ref, off),
                    child: const Text("Choose Room"),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showRoomModal(BuildContext context, WidgetRef ref, Offering offering) {
    final nights = stayNightsInclusive(firstNight, lastNight);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Consumer(
          builder: (context, ref, _) {
            final roomsAsync = ref.watch(
              roomAvailabilityProvider((
                hotelId: hotelId,
                offeringId: offering.id,
                startdate: firstNight,
                enddate: lastNight,
              )),
            );

            return roomsAsync.when(
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Center(child: Text(userMessageForError(err))),
              // check if rooms list is empty and show message
              data: (rooms) {
                if (rooms.isEmpty) {
                  return const SizedBox(
                    height: 220,
                    child: Center(
                        child: Text("No rooms available for this offering.")),
                  );
                }
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offering.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${formatYmd(firstNight)} -> ${formatYmd(lastNight)}  ($nights night(s))',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 320,
                          child: ListView.separated(
                            itemCount: rooms.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final room = rooms[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text("Room ${room.number}"),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    final booking = BookingInput(
                                      id: const Uuid().v4(),
                                      hotel: hotel,
                                      startDate: firstNight,
                                      endDate: lastNight,
                                      items: const [],
                                    );

                                    final item = BookingItemInput(
                                      room: room,
                                      offering: offering,
                                    );

                                    try {
                                      ref
                                          .read(bookingCartProvider.notifier)
                                          .addRoom(
                                            booking: booking,
                                            item: item,
                                          );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Room added to cart'),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(userMessageForError(e))),
                                      );
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: const Text("Add"),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
