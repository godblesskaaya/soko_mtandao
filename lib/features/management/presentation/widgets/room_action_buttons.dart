import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import '../riverpod/manager_room_actions_provider.dart';

enum DateSelectionMode { single, range, multiple }

class RoomActions extends ConsumerStatefulWidget {
  final String roomId;
  const RoomActions({super.key, required this.roomId});

  @override
  ConsumerState<RoomActions> createState() => _RoomActionsState();
}

class _RoomActionsState extends ConsumerState<RoomActions> {
  RoomStatusType? selectedStatus;
  DateSelectionMode dateMode = DateSelectionMode.single;

  DateTime? singleDate;
  DateTimeRange? dateRange;
  List<DateTime> multipleDates = [];
  final TextEditingController noteController = TextEditingController();

  Future<void> pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: singleDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => singleDate = picked);
  }

  Future<void> pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: dateRange ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 1))),
    );
    if (picked != null) setState(() => dateRange = picked);
  }

  Future<void> pickMultipleDates() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && !multipleDates.contains(picked)) {
      setState(() => multipleDates.add(picked));
    }
  }

  Future<void> submit() async {
    if (selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a status.')),
      );
      return;
    }

    final newStatus = RoomStatus(
      roomId: widget.roomId,
      status: selectedStatus!,
      startDate:
          dateMode == DateSelectionMode.single ? singleDate : dateRange?.start,
      endDate: dateMode == DateSelectionMode.range ? dateRange?.end : null,
      dates: dateMode == DateSelectionMode.multiple ? multipleDates : null,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );

    await ref
        .read(managerRoomActionsProvider.notifier)
        .updateRoomStatus(newStatus);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room status updated successfully!')),
      );
      setState(() {
        selectedStatus = null;
        dateRange = null;
        singleDate = null;
        multipleDates.clear();
        noteController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(managerRoomActionsProvider);
    final isLoading = actionState.isLoading;

    return Card(
      margin: const EdgeInsets.only(top: 20),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Room Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Status dropdown
            DropdownButtonFormField<RoomStatusType>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: "Select Room Status",
                border: OutlineInputBorder(),
              ),
              items: RoomStatusType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.name),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => selectedStatus = val),
            ),
            const SizedBox(height: 16),

            // Date mode selection
            DropdownButtonFormField<DateSelectionMode>(
              value: dateMode,
              decoration: const InputDecoration(
                labelText: "Date Selection Type",
                border: OutlineInputBorder(),
              ),
              items: DateSelectionMode.values
                  .map((mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.name),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => dateMode = val!),
            ),
            const SizedBox(height: 16),

            // Date inputs depending on mode
            if (dateMode == DateSelectionMode.single)
              ListTile(
                title: Text(singleDate == null
                    ? 'Select a date'
                    : singleDate!.toLocal().toString().split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: pickSingleDate,
              ),
            if (dateMode == DateSelectionMode.range)
              ListTile(
                title: Text(dateRange == null
                    ? 'Select date range'
                    : '${dateRange!.start.toLocal().toString().split(' ')[0]} → ${dateRange!.end.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.date_range),
                onTap: pickDateRange,
              ),
            if (dateMode == DateSelectionMode.multiple)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: multipleDates
                        .map(
                          (d) => Chip(
                            label: Text(d.toLocal().toString().split(' ')[0]),
                            onDeleted: () =>
                                setState(() => multipleDates.remove(d)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Date'),
                    onPressed: pickMultipleDates,
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Note input
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: "Add Note (optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(isLoading ? "Saving..." : "Update Room Status"),
                onPressed: isLoading ? null : submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
