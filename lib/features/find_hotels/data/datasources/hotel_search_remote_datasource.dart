import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/hotel_entity.dart';
import '../../domain/entities/hotel_search_params.dart';

class HotelSearchRemoteDataSource {
  final SupabaseClient client;

  HotelSearchRemoteDataSource(this.client);

  Future<List<HotelEntity>> searchHotels(HotelSearchParams params) async {
    print('Search Query: ${params.searchQuery}, Region: ${params.region}, City: ${params.city}, Min Price: ${params.minPrice}, Max Price: ${params.maxPrice}, Guests: ${params.guests}, Start Date: ${params.startDate}, End Date: ${params.endDate}, Sort Option: ${params.sortOption}, Limit: ${params.limit}, Offset: ${params.offset}');
    final response = await client.rpc(
      'search_hotels_advanced',
      params: {
        'search_query': params.searchQuery,
        'region_filter': params.region,
        'city_filter': params.city,
        'min_price': params.minPrice,
        'max_price': params.maxPrice,
        'guests': params.guests,
        'start_date': params.startDate?.toIso8601String(),
        'end_date': params.endDate?.toIso8601String(),
        'sort_option': params.sortOption,
        'limit_count': params.limit,
        'offset_count': params.offset,
      },
    );

    print (response);
    if (response == null || response.isEmpty) return [];

    return (response as List<dynamic>).map((row) {
      return HotelEntity(
        id: row['hotel_id'],
        name: row['hotel_name'],
        address: row['hotel_address'],
        city: row['city'],
        region: row['region'],
        country: row['country'],
        rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
        images: row['images'] is String ? List<String>.from(jsonDecode(row['images'])) :
        (row['images'] as List<dynamic>?)
              ?.map((image) => image.toString())
              .toList() ??
          [],
        availableRooms: row['available_rooms'],
        cheapestPrice: (row['cheapest_price'] as num).toDouble(),
      );
    }).toList();
  }
}
