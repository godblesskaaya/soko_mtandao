import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/widgets/hotel_card.dart';
import 'package:soko_mtandao/widgets/app_state_view.dart';

class HotelListWidget extends StatefulWidget {
  final List hotels;
  final bool isLoading;
  final bool hasMore;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final VoidCallback onLoadMore;

  const HotelListWidget({
    super.key,
    required this.hotels,
    required this.isLoading,
    required this.hasMore,
    this.checkIn,
    this.checkOut,
    required this.onLoadMore,
  });

  @override
  State<HotelListWidget> createState() => _HotelListWidgetState();
}

class _HotelListWidgetState extends State<HotelListWidget> {
  final ScrollController _controller = ScrollController();

  void _onScroll() {
    if (_controller.position.pixels >=
            _controller.position.maxScrollExtent - 100 &&
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
    if (widget.hotels.isEmpty && !widget.isLoading) {
      return AppStateView.empty(
        title: 'No hotels found',
        subtitle: 'Try changing dates, destination, or filters.',
      );
    }

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

        return HotelCard(
          hotel: hotel,
          onTap: () {
            final queryParameters = <String, String>{};
            if (widget.checkIn != null && widget.checkOut != null) {
              queryParameters['firstNight'] = formatYmd(widget.checkIn!);
              queryParameters['lastNight'] = formatYmd(widget.checkOut!);
            }
            context.pushNamed(
              "hotelDetail",
              pathParameters: {"hotelId": hotel.id},
              queryParameters: queryParameters.isEmpty
                  ? <String, dynamic>{}
                  : Map<String, dynamic>.from(queryParameters),
            );
          },
        );
      },
    );
  }
}
