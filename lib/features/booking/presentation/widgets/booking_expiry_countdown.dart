import 'dart:async';
import 'package:flutter/material.dart';

class BookingExpiryCountdown extends StatefulWidget {
  final DateTime expiresAt;
  final TextStyle? style;

  const BookingExpiryCountdown({
    super.key,
    required this.expiresAt,
    this.style,
  });

  @override
  State<BookingExpiryCountdown> createState() => _BookingExpiryCountdownState();
}

class _BookingExpiryCountdownState extends State<BookingExpiryCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant BookingExpiryCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _tick();
    }
  }

  void _tick() {
    final now = DateTime.now();
    final diff = widget.expiresAt.difference(now);
    if (!mounted) return;
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final isNearExpiry = _remaining <= const Duration(minutes: 1);

    return Text(
      'Time left to complete payment: $hours:$minutes:$seconds',
      style: (widget.style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
          color: isNearExpiry ? Colors.red : Colors.orange.shade800,
          fontWeight: FontWeight.w600),
    );
  }
}
