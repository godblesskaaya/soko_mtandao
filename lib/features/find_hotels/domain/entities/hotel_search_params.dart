class HotelSearchParams {
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
}
