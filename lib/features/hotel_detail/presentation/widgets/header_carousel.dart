import 'package:flutter/widgets.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/hotel.dart';

class HeaderCarousel extends StatelessWidget {
  final Hotel hotel;
  const HeaderCarousel({required this.hotel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: hotel.images.length,
        itemBuilder: (context, index) {
          return Image.network(
            hotel.images[index],
            fit: BoxFit.cover,
            width: double.infinity,
          );
        },
      ),
    );
  }
}
