import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_offering_providers.dart';

class AddOfferingScreen extends ConsumerStatefulWidget {
  final String hotelId;
  const AddOfferingScreen({super.key, required this.hotelId});

  @override
  ConsumerState<AddOfferingScreen> createState() => _AddOfferingScreenState();
}

class _AddOfferingScreenState extends ConsumerState<AddOfferingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxGuestsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final addOfferingState = ref.watch(addOfferingProvider);

    ref.listen(addOfferingProvider, (prev, next) {
      next.whenData((result) {
        result?.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          ),
          (offering) {
            if (offering != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Offering added: ${offering.title}')),
              );
            }
          },
        );
      });
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Add Offering')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Enter title' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Base Price'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _maxGuestsController,
                decoration: const InputDecoration(labelText: 'Max Guests'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final offering = ManagerOffering(
                      id: '',
                      hotelId: widget.hotelId,
                      title: _titleController.text,
                      description: _descriptionController.text,
                      basePrice: double.tryParse(_priceController.text) ?? 0.0,
                      maxGuests: int.tryParse(_maxGuestsController.text) ?? 1,
                    );
                    ref.read(addOfferingProvider.notifier).addOffering(offering);
                  }
                },
                child: addOfferingState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Add Offering'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
