import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxLocationPicker extends StatefulWidget {
  final Function(double lat, double lng) onLocationSelected;

  const MapboxLocationPicker({
    super.key,
    required this.onLocationSelected,
  });

  @override
  State<MapboxLocationPicker> createState() => _MapboxLocationPickerState();
}

class _MapboxLocationPickerState extends State<MapboxLocationPicker> {
  MapboxMap? _map;
  PointAnnotationManager? _pointManager;
  PointAnnotation? _marker;

  double? selectedLat;
  double? selectedLng;

  @override
  void initState() {
    super.initState();
  }

  /// Initialize PointAnnotationManager and drag events
  Future<void> _initMarkerManager() async {
    _pointManager = await _map?.annotations.createPointAnnotationManager();

    // Register drag callbacks
    _pointManager?.dragEvents(
      onBegin: (annotation) {
        print("Drag started: ${annotation.id}");
      },
      onChanged: (annotation) {
        selectedLat = annotation.geometry.coordinates.lat as double?;
        selectedLng = annotation.geometry.coordinates.lng as double?;
        // update marker position
        setState(() {});
      },
      onEnd: (annotation) {
        print("Drag ended at: $selectedLat, $selectedLng");
      },
    );
  }

  /// Add or move marker
  Future<void> _setMarker(double lat, double lng) async {
    selectedLat = lat;
    selectedLng = lng;
    final Uint8List iconImage = await rootBundle.load('assets/icons/hotel_icon_blue.png').then((byteData) => byteData.buffer.asUint8List());

    // Remove previous marker
    if (_marker != null) {
      await _pointManager?.delete(_marker!);
    }

    // Add new marker
    _marker = await _pointManager?.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        image: iconImage, // default Mapbox pin
        iconSize: 0.6,
        iconAnchor: IconAnchor.BOTTOM,
        isDraggable: true, // enable drag
      ),
    );

    setState(() {});
  }

  /// Use current location
  Future<void> _useCurrentLocation() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    // Check service
    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await geo.Geolocator.openLocationSettings();
      return;
    }

    // Check permission
    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }

    if (permission == geo.LocationPermission.deniedForever) return;

    // Get current position
    geo.Position pos = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );

    final lat = pos.latitude;
    final lng = pos.longitude;

    // Move map
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 500),
    );

    _setMarker(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        actions: [
          TextButton(
            onPressed: () {
              if (selectedLat != null && selectedLng != null) {
                widget.onLocationSelected(selectedLat!, selectedLng!);
                Navigator.of(context).pop();
              }
            },
            child: const Text("Save", style: TextStyle(color: Color.fromARGB(255, 134, 174, 242))),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapbox_location_picker"),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(39.2083, -6.7924)), // Dar city
              zoom: 12,
            ),
            onMapCreated: (controller) async {
              _map = controller;
              await _initMarkerManager();
            },
            onTapListener: (MapContentGestureContext context) {
              final lat = context.point.coordinates.lat;
              final lng = context.point.coordinates.lng;
              _setMarker(lat.toDouble(), lng.toDouble());
            },
          ),

          // "Use My Location" button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: _useCurrentLocation,
              label: const Text("Use my location"),
              icon: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
