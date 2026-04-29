import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/hotel.dart';

class HotelPolicySection extends StatelessWidget {
  const HotelPolicySection({
    super.key,
    required this.hotel,
    this.title = 'Stay rules & check-in',
    this.compact = false,
  });

  final Hotel hotel;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasPolicies = hotel.checkInFrom != null ||
        hotel.checkInUntil != null ||
        hotel.checkOutUntil != null ||
        hotel.stayRules.isNotEmpty ||
        hotel.checkInRequirements.isNotEmpty;
    if (!hasPolicies) return const SizedBox.shrink();

    final titleStyle = compact
        ? Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_folder_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: titleStyle)),
            ],
          ),
          if (hotel.checkInFrom != null ||
              hotel.checkInUntil != null ||
              hotel.checkOutUntil != null) ...[
            const SizedBox(height: 10),
            if (hotel.checkInFrom != null || hotel.checkInUntil != null)
              Text(
                'Check-in: ${_formatWindow(hotel.checkInFrom, hotel.checkInUntil)}',
              ),
            if (hotel.checkOutUntil != null)
              Text('Check-out: by ${hotel.checkOutUntil}'),
          ],
          if (hotel.stayRules.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Stay rules',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ...hotel.stayRules.map((rule) => _PolicyLine(text: rule)),
          ],
          if (hotel.checkInRequirements.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Check-in requirements',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ...hotel.checkInRequirements
                .map((requirement) => _PolicyLine(text: requirement)),
          ],
        ],
      ),
    );
  }

  String _formatWindow(String? from, String? until) {
    if (from != null && until != null) return '$from - $until';
    if (from != null) return 'from $from';
    if (until != null) return 'until $until';
    return 'See hotel instructions';
  }
}

class _PolicyLine extends StatelessWidget {
  const _PolicyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u2022 '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
