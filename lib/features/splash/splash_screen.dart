import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/splash/splash_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();

}

class _SplashScreenState extends ConsumerState<SplashScreen>
  with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(splashRedirectProvider);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String>>(splashRedirectProvider, (previous, next) {
      next.whenData((route) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Use router to navigate (router is set to use named routes)
            context.go(route);
          });
        }
      });

      if (next is AsyncError) {
        debugPrint('Error during splash redirect: ${next.error}');
        if (mounted) context.goNamed('guestHome');
      }
    });

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 6, 101, 153),
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation.value,
              child: Text(
                'Soko Mtandao',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
