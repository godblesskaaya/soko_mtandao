import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/find_hotels/domain/entities/hotel_search_state.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/riverpod/hotel_search_notifier.dart';
import '../../domain/usecases/search_hotels.dart';
import '../../data/repositories/hotel_search_repository_impl.dart';
import '../../data/datasources/hotel_search_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final hotelSearchUseCaseProvider = Provider((ref) {
  final client = Supabase.instance.client;
  final datasource = HotelSearchRemoteDataSource(client);
  final repo = HotelSearchRepositoryImpl(datasource);
  return SearchHotels(repo);
});

final hotelSearchProvider =
    StateNotifierProvider<HotelSearchNotifier, HotelSearchState>(
        (ref) => HotelSearchNotifier(ref.read(hotelSearchUseCaseProvider)));

