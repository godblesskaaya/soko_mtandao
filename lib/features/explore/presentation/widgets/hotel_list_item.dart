import 'package:flutter/material.dart';
import '../../domain/entities/hotel.dart';

class HotelListItem extends StatelessWidget {
  final Hotel hotel;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  const HotelListItem({
    super.key,
    required this.hotel,
    required this.highlighted,
    required this.onTap,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: hotel.imageUrl != null ? NetworkImage(hotel.imageUrl!) : null,
        child: hotel.imageUrl == null ? const Icon(Icons.hotel) : null,
      ),
      title: Text(hotel.name, style: TextStyle(fontWeight: highlighted ? FontWeight.bold : FontWeight.w600)),
      subtitle: hotel.description != null ? Text(hotel.description!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: IconButton(icon: const Icon(Icons.chevron_right), onPressed: onDetails),
    );
  }
}
