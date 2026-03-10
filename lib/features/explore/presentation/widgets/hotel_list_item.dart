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
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: hotel.imageUrl != null
              ? Image.network(
                  hotel.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey.shade300),
                )
              : Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.hotel),
                ),
        ),
      ),
      title: Text(hotel.name,
          style: TextStyle(
              fontWeight: highlighted ? FontWeight.bold : FontWeight.w600)),
      subtitle: hotel.description != null
          ? Text(
              '${hotel.description}  |  ${hotel.availableRooms} rooms',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text('${hotel.availableRooms} rooms'),
      trailing: IconButton(
          icon: const Icon(Icons.chevron_right), onPressed: onDetails),
    );
  }
}
