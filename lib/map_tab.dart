import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late GoogleMapController mapController;
  final TextEditingController _searchController = TextEditingController();

  // ⚠️ YOUR GOOGLE MAPS API KEY
  final String googleAPIKey = "AIzaSyDSancgtsmUfagoV1aW20WXv1HfvsdwAF8";

  static const LatLng _colombo = LatLng(6.9271, 79.8612);

  // --- State Variables ---
  List<dynamic> _placeList = [];
  Set<Polyline> _polylines = {}; // Removed 'final' to allow clean redraws
  LatLng? _currentPosition;
  LatLng? _selectedDestination;

  // Removed 'final' so we can cleanly update markers without map glitches
  Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('rest_1'),
      position: LatLng(6.9281, 79.8622),
      infoWindow: InfoWindow(title: 'Culinae Bistro', snippet: 'Best pasta in town'),
    ),
  };

  final String _mapStyle = '''
  [
    {"elementType": "geometry.fill", "stylers": [{"color": "#FFF3E3"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#EAD8C0"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#A5C9CA"}]},
    {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "on"}]},
    {"featureType": "poi.business", "stylers": [{"visibility": "on"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // --- GPS Logic ---
  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
    );
  }

  // --- 1. Fetch Suggestions as user types ---
  void _getSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _placeList = []);
      return;
    }

    String request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleAPIKey&components=country:lk';

    var response = await http.get(Uri.parse(request));
    if (response.statusCode == 200) {
      setState(() {
        _placeList = json.decode(response.body)['predictions'];
      });
    }
  }

  // --- 2. Navigate to Selected Suggestion ---
  Future<void> _selectPlaceAndNavigate(String address) async {
    setState(() {
      _searchController.text = address;
      _placeList = [];
      _polylines = {}; // Cleanly clear old routes
    });
    FocusScope.of(context).unfocus();

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _selectedDestination = LatLng(locations.first.latitude, locations.first.longitude);

          // Remove the OLD search marker if it exists so we don't clutter the map
          _markers.removeWhere((m) => m.markerId.value == 'searched_location');

          // Add the NEW marker
          _markers.add(
            Marker(
              markerId: const MarkerId('searched_location'),
              position: _selectedDestination!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );

          // Re-assign the set to force GoogleMap to redraw instantly
          _markers = Set.from(_markers);
        });

        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedDestination!, 14.0),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found.')));
      }
    }
  }

  // --- 3. Draw the Route ---
  Future<void> _getDirections() async {
    if (_currentPosition == null || _selectedDestination == null) return;

    PolylinePoints polylinePoints = PolylinePoints(apiKey: googleAPIKey);

    RoutesApiResponse response = await polylinePoints.getRouteBetweenCoordinatesV2(
      request: RoutesApiRequest(
        origin: PointLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        destination: PointLatLng(_selectedDestination!.latitude, _selectedDestination!.longitude),
        travelMode: TravelMode.driving,
      ),
    );

    PolylineResult result = polylinePoints.convertToLegacyResult(response);

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = [];
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      setState(() {
        // Re-assign the entire polylines set for a clean UI update
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            color: const Color(0xFF4A1F1F),
            points: polylineCoordinates,
            width: 5,
          ),
        };
      });

      // Zoom out to perfectly fit both the origin and destination on screen
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude <= _selectedDestination!.latitude ? _currentPosition!.latitude : _selectedDestination!.latitude,
          _currentPosition!.longitude <= _selectedDestination!.longitude ? _currentPosition!.longitude : _selectedDestination!.longitude,
        ),
        northeast: LatLng(
          _currentPosition!.latitude <= _selectedDestination!.latitude ? _selectedDestination!.latitude : _currentPosition!.latitude,
          _currentPosition!.longitude <= _selectedDestination!.longitude ? _selectedDestination!.longitude : _currentPosition!.longitude,
        ),
      );
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60)); // Slightly more padding
    } else {
      // If Google can't find a route (e.g. crossing an ocean or API limits), show an error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find a driving route to this location.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) => mapController = controller,
          style: _mapStyle,
          initialCameraPosition: const CameraPosition(target: _colombo, zoom: 13.0),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E3),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _getSuggestions(value),
                  decoration: InputDecoration(
                    hintText: 'Search for places, cities...',
                    hintStyle: TextStyle(color: Colors.brown.shade300, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4A1F1F)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _placeList = [];
                          _polylines = {};
                          _selectedDestination = null;
                          _markers.removeWhere((m) => m.markerId.value == 'searched_location');
                          _markers = Set.from(_markers);
                        });
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),

              if (_placeList.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _placeList.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Color(0xFF4A1F1F)),
                        title: Text(_placeList[index]['description']),
                        onTap: () {
                          _selectPlaceAndNavigate(_placeList[index]['description']);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        if (_selectedDestination != null && _polylines.isEmpty)
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _getDirections,
              backgroundColor: const Color(0xFF4A1F1F),
              foregroundColor: const Color(0xFFFFF3E3),
              icon: const Icon(Icons.directions),
              label: const Text("Directions", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF4A1F1F),
            foregroundColor: const Color(0xFFFFF3E3),
            onPressed: _getUserLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}