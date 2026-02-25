import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/widgets/hotel_card.dart';

class HotelListWidget extends StatefulWidget {
  final List hotels;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const HotelListWidget({
    super.key,
    required this.hotels,
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  State<HotelListWidget> createState() => _HotelListWidgetState();
}

class _HotelListWidgetState extends State<HotelListWidget> {
  final ScrollController _controller = ScrollController();

  void _onScroll() {
    if (_controller.position.pixels >= _controller.position.maxScrollExtent - 100 &&
        !widget.isLoading &&
        widget.hasMore) {
      widget.onLoadMore();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      itemCount: widget.hotels.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.hotels.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final hotel = widget.hotels[index];

        return HotelCard(hotel: hotel,
          onTap: () {
                      context.pushNamed("hotelDetail",
                          pathParameters: {"hotelId": hotel.id});
                    },
        );
      },
    );
  }
}
