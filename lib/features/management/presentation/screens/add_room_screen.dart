import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/data/models/manager_room_model.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_offering_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_room_providers.dart';
import 'package:soko_mtandao/widgets/dynamic_dropdown_field.dart';

class AddRoomScreen extends ConsumerStatefulWidget {
  final String hotelId;
  const AddRoomScreen({super.key, required this.hotelId});

  @override
  ConsumerState<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends ConsumerState<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  String? selectedOfferingId;
  final selectedOfferingProvider = StateProvider<ManagerOffering?>((ref) => null);

  @override
  Widget build(BuildContext context) {
    final addRoomState = ref.watch(addRoomProvider);
    var selectedOffering = ref.watch(selectedOfferingProvider);

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Add Room')),
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
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
                validator: (value) => value!.isEmpty ? 'Enter room number' : null,
              ),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final room = ManagerRoom(
                      id: '',
                      hotelId: widget.hotelId,
                      offeringId: selectedOfferingId!,
                      roomNumber: _roomNumberController.text,
                      capacity: int.tryParse(_capacityController.text) ?? 1,
                      isActive: true,
                    );
                    print(room.offeringId);
                    print(ManagerRoomModel.fromEntity(room).toJson());
                    ref.read(addRoomProvider.notifier).addRoom(room);
                  }
                },
                child: addRoomState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Add Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
