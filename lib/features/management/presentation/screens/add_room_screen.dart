import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/edit_room_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_offering_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_room_providers.dart';
import 'package:soko_mtandao/widgets/dynamic_dropdown_field.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String hotelId;
  final String? roomId;
  const RoomScreen({super.key, required this.hotelId, this.roomId});

  bool get isEditing => roomId != null;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  String? selectedOfferingId;
  bool _initialized = false;

  @override
  void dispose() {
    _roomNumberController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _populateFields(ManagerRoom room) {
    if (_initialized) return;

    _roomNumberController.text = room.roomNumber;
    _capacityController.text = room.capacity.toString();
    selectedOfferingId = room.offeringId;

    _initialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final room = ManagerRoom(
      id: widget.roomId ?? '',
      hotelId: widget.hotelId,
      offeringId: selectedOfferingId!,
      roomNumber: _roomNumberController.text,
      capacity: int.tryParse(_capacityController.text) ?? 1,
      isActive: true,
    );

    if (widget.isEditing) {
      final roomMutationNotifier = ref.read(RoomMutationProvider.notifier);
      await roomMutationNotifier.updateRoom(room);
    } else {
      await ref.read(addRoomProvider.notifier).addRoom(room);
    }

    ref.invalidate( roomsProvider(widget.hotelId) );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final roomMutationNotifier = ref.read(RoomMutationProvider.notifier);
      await roomMutationNotifier.deleteRoom(widget.roomId!);

      ref.invalidate( roomsProvider(widget.hotelId) );

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    ref.listen(RoomMutationProvider, (prev, next) {
      next.whenData((either) {
        either?.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          ),
          (_) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEditing
                    ? 'Room updated successfully'
                    : 'Room deleted successfully',
              ),
            ),
          ),
        );
      });
    });

    ref.listen(addRoomProvider, (prev, next) {
      next.whenData((result) {
        result?.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          ),
          (room) {
            if (room != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Room added successfully: ${room.roomNumber}')),
              );
            }
          },
        );
      });
    });

    if (widget.isEditing) {
      final roomAsync = ref.watch(roomProvider(widget.roomId!));
      return roomAsync.when(
        data: (room) {
          _populateFields(room);
          return _buildForm(context);
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          body: Center(child: Text(userMessageForError(err))),
        ),
      );
    } else {
      return _buildForm(context);
    }
  }

  Widget _buildForm(BuildContext context) {
    final addRoomState = ref.watch(addRoomProvider);
    final roomMutationState = ref.watch(RoomMutationProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Room' : 'Add Room'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
          ],
        ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              AsyncDropdownField<ManagerOffering, String>(
                providerBuilder: (ref) => offeringsProvider(widget.hotelId), 
                getLabel: (o) => o.title,
                getId: (o) => o.id!,
                label: 'offering',
                value: selectedOfferingId,
                onChanged: (id) => setState(() {
                  selectedOfferingId = id;
                }),
                onFetch: (ref) async {
                  ref.invalidate(offeringsProvider(widget.hotelId));
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
                validator: (value) => value!.isEmpty ? 'Enter room number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  addRoomState.isLoading || roomMutationState.isLoading
                      ? null
                      : _submit();
                },
                child: addRoomState.isLoading || roomMutationState.isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.isEditing ? 'Update Room' : 'Add Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
