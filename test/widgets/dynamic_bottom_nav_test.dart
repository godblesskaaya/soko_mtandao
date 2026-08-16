import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/router/nav_config.dart';
import 'package:soko_mtandao/widgets/dynamic_bottom_nav.dart';

void main() {
  testWidgets('DynamicBottomNav applies safe area for system navigation insets',
      (tester) async {
    const items = [
      NavItem(
        label: 'Explore',
        icon: Icons.explore,
        routeName: 'explore',
        visibleTo: [UserRole.guest],
      ),
      NavItem(
        label: 'Bookings',
        icon: Icons.calendar_today,
        routeName: 'bookings',
        visibleTo: [UserRole.guest],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 24),
          ),
          child: Scaffold(
            bottomNavigationBar: DynamicBottomNav(
              items: items,
              selectedIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));

    expect(safeArea.top, isFalse);
    expect(safeArea.bottom, isTrue);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
