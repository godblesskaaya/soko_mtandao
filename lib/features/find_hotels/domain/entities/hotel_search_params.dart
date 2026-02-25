class HotelSearchParams {
  static const Set<String> allowedSortOptions = {
    'relevance',
    'price_asc',
    'price_desc',
    'rating_asc',
    'rating_desc',
    'rooms_desc',
    'name_asc',
    'name_desc',
  };

  final String searchQuery;
  final String? region;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final int? guests;
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortOption;
  final int limit;
  final int offset;
  final int page;

  HotelSearchParams({
    this.searchQuery = "",
    this.region,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.guests,
    this.startDate,
    this.endDate,
    this.sortOption = 'relevance',
    this.limit = 20,
    this.offset = 0,
    this.page = 1,
  });

  String? get normalizedRegion {
    final value = region?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String? get normalizedCity {
    final value = city?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String get normalizedSearchQuery => searchQuery.trim();

  String get normalizedSortOption =>
      allowedSortOptions.contains(sortOption) ? sortOption : 'relevance';

  int get effectivePage => page < 1 ? 1 : page;

  int get effectiveLimit => limit < 1 ? 20 : limit;

  int get effectiveOffset {
    if (offset > 0) return offset;
    return (effectivePage - 1) * effectiveLimit;
  }
}
