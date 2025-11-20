import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/hotel.dart';
import '../riverpod/hotels_provider.dart';

class HotelDetailScreen extends ConsumerWidget {
  final String hotelId;
  const HotelDetailScreen({super.key, required this.hotelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelAsync = ref.watch(hotelDetailProvider(hotelId));

    return Scaffold(
      appBar: AppBar(title: const Text('Hotel Details')),
      body: hotelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (hotel) => _Details(hotel: hotel),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final Hotel hotel;
  const _Details({required this.hotel});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (hotel.imageUrl != null)
          Image.network(hotel.imageUrl!, height: 220, width: double.infinity, fit: BoxFit.cover),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hotel.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (hotel.description != null)
                Text(hotel.description!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Text('Location: ${hotel.location.lat.toStringAsFixed(4)}, ${hotel.location.lng.toStringAsFixed(4)}'),
              const SizedBox(height: 24),
              const Text('Offerings (coming next)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('We will list room types here with availability and prices.'),
            ],
          ),
        ),
      ],
    );
  }
}
