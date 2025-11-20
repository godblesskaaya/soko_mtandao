import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:soko_mtandao/features/explore/domain/entities/hotel.dart';
import 'package:soko_mtandao/features/explore/presentation/riverpod/map_state.dart' as custom_map_state;
import 'package:soko_mtandao/features/explore/presentation/widgets/hotel_list_item.dart';
import '../../../../core/config/map_config.dart';
import '../../../../router/route_names.dart';

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  MapboxMap? _map;
  PointAnnotationManager? _pinManager;
  Cancelable? _pointAnnotationTapSubscription;
  Timer? _debounce;
  String? _highlightedId;
  final Map<String, String> annotationToHotelId = {};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleBoundsUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      if (_map == null) return;
      final camera = await _map!.getCameraState();
      final bounds = await _map!.cameraForCoordinateBounds(
        /* Mbx */CoordinateBounds(
          southwest: Point(coordinates: Position(camera.center.coordinates.lng - 0.05, camera.center.coordinates.lat - 0.05)),
          northeast: Point(coordinates: Position(camera.center.coordinates.lng + 0.05, camera.center.coordinates.lat + 0.05)), infiniteBounds: false,
        ),
        MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
        0, // padding
        0, // bearing
        0, // pitch
        ScreenCoordinate(x: 0, y: 0),
      );
      // If API above doesn’t yield real screen bounds, we’ll approximate via zoom:
      final lat = camera.center.coordinates.lat;
      final lng = camera.center.coordinates.lng;
      final zoom = camera.zoom;
      final delta = _latLngDeltaForZoom(zoom);
      final b = (south: lat - delta, west: lng - delta, north: lat + delta, east: lng + delta);

      ref.read(custom_map_state.cameraStateProvider.notifier).state = custom_map_state.CameraState(
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        zoom: zoom,
        bounds: b,
      );
    });
  }

  double _latLngDeltaForZoom(double zoom) {
    // crude heuristic: tighter box when zooming in
    if (zoom >= 15) return 0.01;
    if (zoom >= 13) return 0.02;
    if (zoom >= 12) return 0.03;
    if (zoom >= 11) return 0.05;
    return 0.1;
  }

  Future<void> _initPins(List<Hotel> hotels) async {
    if (_map == null) return;
    _pinManager ??= await _map!.annotations.createPointAnnotationManager();
    await _pinManager!.deleteAll();

    final Uint8List icon = await rootBundle.load("assets/icons/hotel_icon_blue.png").then((value) => value.buffer.asUint8List());
    final Uint8List highlightedIcon = await rootBundle.load("assets/icons/hotel_icon_yellow.png").then((value) => value.buffer.asUint8List());

    _pointAnnotationTapSubscription ??= _pinManager!.tapEvents(onTap: (PointAnnotation ClickedAnnotation) {
      final String? annotationId = ClickedAnnotation.id;
      if (annotationId != null) {
        final hotelId = annotationToHotelId[annotationId];
        
        if (hotelId != null) {
          ref.read(custom_map_state.selectedHotelIdProvider.notifier).state = hotelId;
          setState(() => _highlightedId = hotelId);
        }
      }
    });

    for (final h in hotels) {
      final opts = PointAnnotationOptions(
        geometry: Point(coordinates: Position(h.location.lng, h.location.lat)),
        image: (_highlightedId == h.id) ? highlightedIcon : icon,
        iconSize: 0.3,
        iconAnchor: IconAnchor.BOTTOM,
        textAnchor: TextAnchor.TOP,
        textField: h.name,
        textSize: 12,
      );
      final ann = await _pinManager!.create(opts);

      // Map the annotation ID to hotel ID
      annotationToHotelId[ann.id] = h.id;

      // _pinManager!.addOnPointAnnotationClickListener(AnnotationClickListener(onAnnotationClick: (ann, point) {
      //   ref.read(custom_map_state.selectedHotelIdProvider.notifier).state = h.id;
      //   setState(() => _highlightedId = h.id);
      //   return true;
      // }));
    }
  }

  Future<void> _moveToInitial() async {
    final init = await ref.read(custom_map_state.initialLocationProvider.future);
    await _map?.setCamera(CameraOptions(
      center: Point(coordinates: Position(init.lng, init.lat)),
      zoom: MapConfig.minZoomForData + 1.2,
    ));
    _map?.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hotelsAsync = ref.watch(custom_map_state.hotelsInViewProvider);
    final selectedId = ref.watch(custom_map_state.selectedHotelIdProvider);
    final searchQuery = ref.watch(custom_map_state.exploreSearchQueryProvider);

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('map'),
            styleUri: "mapbox://styles/mapbox/streets-v12",
            // resourceOptions: ResourceOptions(accessToken: MapConfig.mapboxAccessToken),
            onMapCreated: (controller) async {
              _map = controller;
              await _moveToInitial();

              // _map!.gestures.addOnMapIdleListener(MapIdleListener(callback: _scheduleBoundsUpdate));
              // _map!.camera.addListener(CameraChangedListener(callback: (_) => _scheduleBoundsUpdate()));
            },
            onCameraChangeListener: (CameraChangedEventData data){
              _scheduleBoundsUpdate();
            },
            // onMapIdleListener: (mapIdleEventData) => _scheduleBoundsUpdate(),
          ),

          // Top Search Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _SearchBar(
                initial: searchQuery,
                onChanged: (v) => ref.read(custom_map_state.exploreSearchQueryProvider.notifier).state = v,
                onClear: () => ref.read(custom_map_state.exploreSearchQueryProvider.notifier).state = '',
              ),
            ),
          ),

          // Zoom hint overlay
          Consumer(
            builder: (_, r, __) {
              final cam = r.watch(custom_map_state.cameraStateProvider);
              if (cam == null) return const SizedBox.shrink();
              final tooLow = cam.zoom < MapConfig.minZoomForData && (r.read(custom_map_state.exploreSearchQueryProvider).isEmpty);
              if (!tooLow) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(top: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Zoom in to explore hotels', style: TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          ),

          // Draggable Bottom Sheet (List)
          DraggableScrollableSheet(
            initialChildSize: 0.33,
            minChildSize: 0.2,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: const [BoxShadow(blurRadius: 10, spreadRadius: 2)],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2.5))),
                    const SizedBox(height: 8),
                    Expanded(
                      child: hotelsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Failed to fetch hotels.\n$e', textAlign: TextAlign.center),
                        )),
                        data: (hotels) {
                          // Update pins when data changes
                          WidgetsBinding.instance.addPostFrameCallback((_) => _initPins(hotels));

                          if (hotels.isEmpty) {
                            return const Center(child: Text('No hotels here yet.'));
                          }
                          return ListView.separated(
                            controller: scrollController,
                            itemCount: hotels.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final h = hotels[i];
                              final highlighted = h.id == selectedId;
                              return HotelListItem(
                                hotel: h,
                                highlighted: highlighted,
                                onTap: () {
                                  ref.read(custom_map_state.selectedHotelIdProvider.notifier).state = h.id;
                                  setState(() => _highlightedId = h.id);
                                  // _map?.setCamera(CameraOptions(
                                  //   center: Point(coordinates: Position(h.location.lng, h.location.lat)),
                                  //   // zoom: 15,
                                  // ));
                                },
                                onDetails: () {
                                  context.goNamed('hotelDetail', pathParameters: {'hotelId': h.id});
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Simple search bar
class _SearchBar extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBar({required this.initial, required this.onChanged, required this.onClear});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _c;
  @override
  void initState() { super.initState(); _c = TextEditingController(text: widget.initial); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: TextField(
        controller: _c,
        decoration: InputDecoration(
          hintText: 'Search hotels or places',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _c.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _c.clear(); widget.onClear(); setState(() {}); }) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: (v) { widget.onChanged(v); setState(() {}); },
      ),
    );
  }
}
