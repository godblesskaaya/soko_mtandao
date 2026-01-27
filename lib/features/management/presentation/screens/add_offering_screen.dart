import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/edit_offering_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_offering_providers.dart';

class OfferingScreen extends ConsumerStatefulWidget {
  final String hotelId;
  final String? offeringId;
  const OfferingScreen({super.key, required this.hotelId, this.offeringId});

  bool get isEditing => offeringId != null;

  @override
  ConsumerState<OfferingScreen> createState() => _OfferingScreenState();
}

class _OfferingScreenState extends ConsumerState<OfferingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxGuestsController = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxGuestsController.dispose();
    super.dispose();
  }

  void _populateFields(ManagerOffering offering) {
    if (_initialized) return;

    _titleController.text = offering.title;
    _descriptionController.text = offering.description;
    _priceController.text = offering.basePrice.toString();
    _maxGuestsController.text = offering.maxGuests.toString();

    _initialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final offering = ManagerOffering(
      id: widget.offeringId ?? '',
      hotelId: widget.hotelId,
      title: _titleController.text,
      description: _descriptionController.text,
      basePrice: double.tryParse(_priceController.text) ?? 0.0,
      maxGuests: int.tryParse(_maxGuestsController.text) ?? 1,
    );

    if (widget.isEditing) {
      await ref.read(offeringMutationProvider.notifier).updateOffering(offering);
    } else {
      await ref.read(addOfferingProvider.notifier).addOffering(offering);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this offering?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(offeringMutationProvider.notifier)
          .deleteOffering(widget.offeringId!);

      ref.invalidate(offeringsProvider(widget.hotelId));
      if (mounted) Navigator.of(context).pop(); // Go back after deletion
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(offeringMutationProvider, (prev, next) {
      next.whenData((result) {
        result.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          ),
          (offering) {
            if (offering != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(widget.isEditing
                        ? 'Offering updated: ${offering.title}'
                        : 'Offering added: ${offering.title}')),
              );
              Navigator.of(context).pop(); // Go back after success
            }
          },
        );
      });
    });

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

    if (widget.isEditing) {
      // Editing existing offering
      final offeringAsync = ref.watch(offeringDetailsProvider(widget.offeringId!));
      return offeringAsync.when(
        data: (offering) { 
          _populateFields(offering); 
          return _buildForm(context);
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      );
    } else {
      // Adding new offering
      return _buildForm(context);
    }
  }
    
Widget _buildForm(BuildContext context) {
    final addOfferingState = ref.watch(addOfferingProvider);
    final mutationState = ref.watch(offeringMutationProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Offering' : 'Add Offering'),
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Base Price'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxGuestsController,
                decoration: const InputDecoration(labelText: 'Max Guests'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  mutationState.isLoading || addOfferingState.isLoading
                      ? null
                      : _submit();
                },
                child: addOfferingState.isLoading || mutationState.isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.isEditing ? 'Update Offering' : 'Add Offering'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
