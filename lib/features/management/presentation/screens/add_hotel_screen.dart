// features/manager/presentation/screens/add_hotel_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/add_hotel_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_amenity_provider.dart';
import 'package:soko_mtandao/features/management/presentation/widgets/location_picker.dart';
import 'package:soko_mtandao/widgets/dynamic_multiselect_field.dart';
import '../../../hotel_detail/domain/entities/amenity.dart';

class AddHotelScreen extends ConsumerStatefulWidget {
  const AddHotelScreen({super.key});

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
  List<File> images = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _ratingController.dispose();
    _regionController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        images.add(File(pickedFile.path));
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
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

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hotel added successfully')),
        );
        Navigator.pop(context, true); // return success
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addHotelProvider);
    final amenities = ref.watch(managerAmenitiesProvider(NoParams()));
    print("form-level amenities = $amenities");


    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Add New Hotel"),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField("Hotel Name", _nameController),
                    _buildTextField("Address", _addressController),
                    _buildTextField("Description", _descriptionController,
                        maxLines: 3),
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
                              validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
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
                              validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
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
                                      _latController.text = lat.toStringAsFixed(6);
                                      _lngController.text = lng.toStringAsFixed(6);
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
                        keyboard: TextInputType.phone),
                    _buildTextField("Email", _emailController,
                        keyboard: TextInputType.emailAddress),
                    _buildTextField("Website", _websiteController),

                    const SizedBox(height: 16),

                    AsyncMultiSelectField<ManagerAmenity, String>(
                      label: "Amenities",
                      providerBuilder: (ref) => managerAmenitiesProvider(NoParams()),  // or amenitiesProvider(someId)
                      getLabel: (a) => a.name,
                      getId: (a) => a.amenityId,
                      values: selectedAmenities.map((a) => a.amenityId).toList(),
                      onChanged: (ids) {
                        setState(() {
                          selectedAmenities = ids
                              .map((id) => ManagerAmenity(name: id, amenityId: id, category: '', availabilityStatus: '')) // OR lookup real items
                              .toList();
                        });
                      },
                      onFetch: (ref) async {
                        ref.refresh(managerAmenitiesProvider(NoParams()));
                      },
                    ),


                    const SizedBox(height: 16),

                    // Images
                    Align(alignment: Alignment.centerLeft,
                    child: Text("Images",
                        style: Theme.of(context).textTheme.titleMedium,
                        ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      children: images.map((file) => Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.file(file,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  images.remove(file);
                                });
                              }, 
                              icon: const Icon(Icons.close, size: 16, color: Colors.red,)
                              ),
                          ],
                      )).toList(),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text("Add Image"),
                      onPressed: _pickImage,
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: state.isLoading ? null : _submit,
                      child: const Text("Save Hotel"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
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
