import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/edit_offering_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_amenity_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_offering_providers.dart';
import 'package:soko_mtandao/widgets/dynamic_multiselect_field.dart';

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
  final _imageUrlsController = TextEditingController();
  List<String> _selectedAmenityIds = [];

  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxGuestsController.dispose();
    _imageUrlsController.dispose();
    super.dispose();
  }

  void _populateFields(ManagerOffering offering) {
    if (_initialized) return;

    _titleController.text = offering.title;
    _descriptionController.text = offering.description;
    _priceController.text = offering.basePrice.toString();
    _maxGuestsController.text = offering.maxGuests.toString();
    _selectedAmenityIds = offering.amenityIds;
    _imageUrlsController.text = offering.imageUrls.join('\n');

    _initialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final offering = ManagerOffering(
      id: widget.offeringId,
      hotelId: widget.hotelId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      basePrice: double.tryParse(_priceController.text.trim()) ?? 0.0,
      maxGuests: int.tryParse(_maxGuestsController.text.trim()) ?? 1,
      amenityIds: _selectedAmenityIds,
      imageUrls: _imageUrlsController.text
          .split(RegExp(r'[\n,]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );

    final result = widget.isEditing
        ? await ref
            .read(offeringMutationProvider.notifier)
            .updateOffering(offering)
        : await ref.read(addOfferingProvider.notifier).addOffering(offering);

    result.fold(
      (failure) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (savedOffering) {
        ref.invalidate(offeringsProvider(widget.hotelId));
        if (widget.offeringId != null) {
          ref.invalidate(offeringDetailsProvider(widget.offeringId!));
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Offering updated.'
                  : 'Offering added: ${savedOffering?.title ?? offering.title}',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Offering'),
        content: const Text(
          'This makes the offering unavailable. It will be blocked if active or future bookings depend on it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ref
          .read(offeringMutationProvider.notifier)
          .deleteOffering(widget.offeringId!);

      result.fold(
        (failure) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
        (_) {
          ref.invalidate(offeringsProvider(widget.hotelId));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offering archived.')),
          );
          Navigator.of(context).pop(true);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      // Editing existing offering
      final offeringAsync =
          ref.watch(offeringDetailsProvider(widget.offeringId!));
      return offeringAsync.when(
        data: (offering) {
          _populateFields(offering);
          return _buildForm(context);
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, st) =>
            Scaffold(body: Center(child: Text(userMessageForError(e)))),
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
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Offering' : 'Add Offering'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: mutationState.isLoading ? null : _confirmDelete,
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
                validator: (value) {
                  final price = double.tryParse((value ?? '').trim());
                  if (price == null || price <= 0) {
                    return 'Enter a price greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxGuestsController,
                decoration: const InputDecoration(labelText: 'Max Guests'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final guests = int.tryParse((value ?? '').trim());
                  if (guests == null || guests < 1) {
                    return 'Enter at least 1 guest';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AsyncMultiSelectField<ManagerAmenity, String>(
                label: "Amenities",
                provider: managerAmenitiesProvider,
                getLabel: (amenity) => amenity.name,
                getId: (amenity) => amenity.amenityId,
                values: _selectedAmenityIds,
                onChanged: (selectedIds) {
                  setState(() => _selectedAmenityIds = selectedIds);
                },
                validator: (_) => null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlsController,
                decoration: const InputDecoration(
                  labelText: 'Image URLs',
                  helperText: 'One URL per line (or comma-separated)',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: mutationState.isLoading || addOfferingState.isLoading
                    ? null
                    : _submit,
                child: addOfferingState.isLoading || mutationState.isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        widget.isEditing ? 'Update Offering' : 'Add Offering'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
