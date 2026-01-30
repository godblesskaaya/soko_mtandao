// features/manager/presentation/screens/add_hotel_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/editable_image.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/add_hotel_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/edit_hotel_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_amenity_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart' hide addHotelProvider;
import 'package:soko_mtandao/features/management/presentation/widgets/location_picker.dart';
import 'package:soko_mtandao/widgets/dynamic_multiselect_field.dart';
import '../../../hotel_detail/domain/entities/amenity.dart';

class AddHotelScreen extends ConsumerStatefulWidget {
  final String? hotelId;
  const AddHotelScreen({super.key, this.hotelId});

  @override
  ConsumerState<AddHotelScreen> createState() => _AddHotelScreenState();
}

class _AddHotelScreenState extends ConsumerState<AddHotelScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _ratingController = TextEditingController(text: "0.0");
  final _regionController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _roomsController = TextEditingController(text: "0");

  // State
  List<ManagerAmenity> selectedAmenities = [];
  List<EditableImage> images = [];

  final ImagePicker _picker = ImagePicker();

  bool _initialized = false;

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _addressController,
      _descriptionController,
      _latController,
      _lngController,
      _ratingController,
      _roomsController,
      _regionController,
      _countryController,
      _cityController,
      _phoneController,
      _emailController,
      _websiteController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// -------- PREFILL FOR EDIT --------
  void _initializeFromHotel(hotel) {
    _nameController.text = hotel.name;
    _addressController.text = hotel.address ?? '';
    _descriptionController.text = hotel.description ?? '';
    _latController.text = hotel.lat.toString();
    _lngController.text = hotel.lng.toString();
    _ratingController.text = hotel.rating.toString();
    _roomsController.text = hotel.totalRooms.toString();
    _regionController.text = hotel.region;
    _countryController.text = hotel.country;
    _cityController.text = hotel.city;
    _phoneController.text = hotel.phoneNumber ?? '';
    _emailController.text = hotel.email ?? '';
    _websiteController.text = hotel.website ?? '';

    images = hotel.images
        .map<EditableImage>((url) => EditableImage.remote(url))
        .toList();

    selectedAmenities = hotel.amenities;
    _initialized = true;
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );

    if (file != null) {
      setState(() {
        images.add(EditableImage.local(file.path));
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        if (widget.hotelId == null) {
          final notifier = ref.read(addHotelProvider.notifier);
        
          await notifier.addHotel(
            name: _nameController.text,
            address: _addressController.text,
            description: _descriptionController.text,
            images: images.map((image) => image.path).toList(),
            amenities: selectedAmenities,
            lat: _latController.text,
            lng: _lngController.text,
            rating: double.tryParse(_ratingController.text) ?? 0.0,
            totalRooms: int.tryParse(_roomsController.text) ?? 0,
            region: _regionController.text,
            country: _countryController.text,
            city: _cityController.text,
            phoneNumber: _phoneController.text,
            email: _emailController.text,
            website: _websiteController.text.isNotEmpty ? _websiteController.text : null,
          );
        } else {
          final notifier = ref.read(editHotelProvider.notifier);
        
          await notifier.updateHotel(
            hotelId: widget.hotelId!,
            name: _nameController.text,
            address: _addressController.text,
            description: _descriptionController.text,
            images: images,
            amenities: selectedAmenities,
            lat: double.tryParse(_latController.text) ?? 0.0,
            lng: double.tryParse(_lngController.text) ?? 0.0,
            rating: double.tryParse(_ratingController.text) ?? 0.0,
            totalRooms: int.tryParse(_roomsController.text) ?? 0,
            region: _regionController.text,
            country: _countryController.text,
            city: _cityController.text,
            phoneNumber: _phoneController.text,
            email: _emailController.text,
            website: _websiteController.text.isNotEmpty ? _websiteController.text : null,
          );
        }
        
        if(widget.hotelId != null) {
          ref.invalidate(hotelDetailProvider(widget.hotelId!));
        }
        
        ref.invalidate(managerHotelsProvider);
        
        if (mounted) {
          // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.hotelId != null ? 'Hotel updated successfully' : 'Hotel added successfully')),
            );
        
          Navigator.pop(context, true); // return success
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addHotelProvider);
    final amenitiesAsync = ref.watch(managerAmenitiesProvider);

/// ------- EDIT MODE -------
    if (widget.hotelId != null) {
      final hotelAsync = ref.watch(
        hotelDetailProvider(widget.hotelId!),
      );

      hotelAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) {
          return Scaffold(
            appBar: AppBar(title: const Text("Edit Hotel")),
            body: Center(child: Text("Error loading hotel: $err")),
          );
        },
        data: (hotel) {
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
             setState(() => _initializeFromHotel(hotel));
            });
          }
          return _buildForm(context, amenitiesAsync);
        },
      );
    }
    // ------- ADD MODE -------
    return _buildForm(context, amenitiesAsync);
  }
  Widget _buildForm(BuildContext context, AsyncValue amenitiesAsync) {
    final editState = ref.watch(editHotelProvider);
    final addState = ref.watch(addHotelProvider);

    return editState.isLoading || addState.isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ======= PAGE TITLE (replaces AppBar) =======
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.hotelId != null ? "Edit Hotel" : "Add New Hotel",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField("Hotel Name", _nameController),
                  _buildTextField("Address", _addressController),
                  _buildTextField("Description", _descriptionController,
                      maxLines: 3),

                  // ---- LOCATION PICKER ----
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            decoration: const InputDecoration(
                              labelText: "Latitude",
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            validator: (val) =>
                                (val == null || val.isEmpty) ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            decoration: const InputDecoration(
                              labelText: "Longitude",
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            validator: (val) =>
                                (val == null || val.isEmpty) ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.map),
                          label: const Text("Select"),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapboxLocationPicker(
                                  onLocationSelected: (lat, lng) {
                                    _latController.text =
                                        lat.toStringAsFixed(6);
                                    _lngController.text =
                                        lng.toStringAsFixed(6);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  _buildTextField("Rating", _ratingController,
                      keyboard: TextInputType.number),
                  _buildTextField("Total Rooms", _roomsController,
                      keyboard: TextInputType.number),
                  _buildTextField("Region", _regionController),
                  _buildTextField("Country", _countryController),
                  _buildTextField("City", _cityController),
                  _buildTextField("Phone Number", _phoneController,
                      keyboard: TextInputType.phone,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
                          if (!phoneRegex.hasMatch(val)) {
                            return 'Please enter a valid phone number';
                          }
                        }
                        return null;
                      }),
                  _buildTextField("Email", _emailController,
                      keyboard: TextInputType.emailAddress,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(val)) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      }),
                  _buildTextField("Website", _websiteController, validator: (val) {
                    if (val != null && val.isNotEmpty) {
                      final uri = Uri.tryParse(val);
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'Please enter a valid URL';
                      }
                    }
                    return null;
                  }, keyboard: TextInputType.url),

                  const SizedBox(height: 16),

                  // ---- AMENITIES ----
                  AsyncMultiSelectField<ManagerAmenity, String>(
                    label: "Amenities",
                    // 1. The provider that fetches the list
                    provider: managerAmenitiesProvider,
                    
                    // 2. How to display the item and identifying it
                    getLabel: (amenity) => amenity.name,
                    getId: (amenity) => amenity.amenityId,
                    
                    // 3. Current selected IDs (mapped from your object list)
                    values: selectedAmenities
                        .map((a) => a.amenityId)
                        .toList(),
                        
                    // 4. Update state when selection changes
                    onChanged: (selectedIds) {
                      // Read the current list from the provider to find the full objects
                      final allAmenities = ref.read(managerAmenitiesProvider).valueOrNull ?? [];

                      setState(() {
                        // Filter the full list to keep only the selected ones
                        selectedAmenities = allAmenities
                            .where((amenity) => selectedIds.contains(amenity.amenityId))
                            .toList();
                      });
                    },
                    
                    // Optional: Add validation if needed
                    validator: (ids) {
                      if (ids == null || ids.isEmpty) {
                        return 'Please select at least one amenity';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ---- IMAGES SECTION ----
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Images",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    children: images
                        .map(
                          (img) => Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Image(
                                  image: img.isRemote
                                      ? NetworkImage(img.path)
                                      : FileImage(File(img.path))
                                          as ImageProvider,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    images.remove(img);
                                  });
                                },
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text("Add Image"),
                    onPressed: _pickImage,
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: editState.isLoading ? null : _submit,
                    child: Text(widget.hotelId == null ? "Save Hotel" : "Update Hotel"),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: (val) =>
            (val == null || val.isEmpty) ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
