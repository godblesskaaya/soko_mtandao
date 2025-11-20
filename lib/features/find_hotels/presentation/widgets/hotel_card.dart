import 'package:flutter/material.dart';
import '../../domain/entities/hotel_entity.dart';

class HotelCard extends StatelessWidget {
  final HotelEntity hotel;
  final VoidCallback? onTap;

  const HotelCard({super.key, required this.hotel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: ListTile(
        // hotel images are a list, display the first one if available in a small size like thumbnail
        onTap: onTap,
        leading: CircleAvatar(
          radius: 40,
          backgroundImage: hotel.images != null && hotel.images!.isNotEmpty
              ? NetworkImage(hotel.images!.first)
              : null,
          child: hotel.images == null || hotel.images!.isEmpty
              ? const Icon(Icons.hotel, size: 20)
              : null,
        ),
        title: Text(hotel.name),
        subtitle: Text("${hotel.city}, ${hotel.region}\nTZS ${hotel.cheapestPrice} / night"),
        trailing: Text("${hotel.availableRooms} rooms"),
      ),
    );
  }
}
