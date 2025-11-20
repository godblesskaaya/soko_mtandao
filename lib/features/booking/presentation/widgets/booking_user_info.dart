import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/router/route_names.dart';

class BookingUserInfo extends StatelessWidget {
  final UserInfo user;
  const BookingUserInfo({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(user.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text(user.phone),
          ],
        ),
        // trailing: TextButton(
        //   onPressed: () {
        //     // Navigate back to user info screen
        //     context.pushNamed(RouteNames.userInfo);
        //   },
        //   child: const Text('Edit'),
        // ),
      ),
    );
  }
}
