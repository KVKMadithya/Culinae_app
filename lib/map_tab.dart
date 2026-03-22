import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'public_store_profile.dart'; // To open menus!

const Color culinaeBrown = Color(0xFF4A1F1F);
const Color culinaeCream = Color(0xFFFFF3E3);

//GOOGLE MAPS API KEY
final String googleAPIKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

const LatLng defaultLocation = LatLng(6.9271, 79.8612); // Colombo

final String mapStyle = '''
[
  {"elementType": "geometry.fill", "stylers": [{"color": "#FFF3E3"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#EAD8C0"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#A5C9CA"}]},
  {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "on"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "on"}]}
]
''';

// ============================================================================
// 1. OWNER MAP TAB (Setting the Store Location)
// ============================================================================
class OwnerMapTab extends StatefulWidget {
  const OwnerMapTab({super.key});
  @override
  State<OwnerMapTab> createState() => _OwnerMapTabState();
}

class _OwnerMapTabState extends State<OwnerMapTab> {
  GoogleMapController? _mapController;
  LatLng? _storeLocation;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placeList = [];
  bool _isManualMode = false;

  @override
  void initState() {
    super.initState();
    _loadStoreLocation();
  }

  Future<void> _loadStoreLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final geoPoint = doc.data()?['storeLocation'] as GeoPoint?;
      if (geoPoint != null) {
        setState(() => _storeLocation = LatLng(geoPoint.latitude, geoPoint.longitude));
      }
    }
  }

  void _getSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _placeList = []);
      return;
    }
    String request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleAPIKey&components=country:lk';
    var response = await http.get(Uri.parse(request));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);

      // 🚨 CATCH GOOGLE'S REJECTION LETTER
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        print("🚨 PLACES API ERROR: ${data['status']} - ${data['error_message']}");
      }

      setState(() => _placeList = data['predictions'] ?? []);
    } else {
      print("🚨 HTTP ERROR: ${response.statusCode}");
    }
  }

  Future<void> _selectPlaceAndNavigate(String address) async {
    setState(() {
      _searchController.text = address;
      _placeList = [];
    });
    FocusScope.of(context).unfocus();

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _storeLocation = LatLng(locations.first.latitude, locations.first.longitude);
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_storeLocation!, 16.0));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found.')));
    }
  }

  Future<void> _confirmLocation() async {
    if (_storeLocation == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'storeLocation': GeoPoint(_storeLocation!.latitude, _storeLocation!.longitude)
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store Location Confirmed! Customers can now find you. 📍'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Store Location', style: TextStyle(color: culinaeBrown)), backgroundColor: culinaeCream, elevation: 0),
      body: Stack(
        children: [
          GoogleMap(
            style: mapStyle,
            initialCameraPosition: CameraPosition(target: _storeLocation ?? defaultLocation, zoom: 14),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (location) {
              if (_isManualMode) {
                setState(() => _storeLocation = location);
              }
            },
            markers: _storeLocation != null ? {Marker(markerId: const MarkerId('store'), position: _storeLocation!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed))} : {},
          ),

          if (!_isManualMode)
            Positioned(
              top: 16, left: 16, right: 16,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: culinaeCream, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))]),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _getSuggestions,
                      decoration: InputDecoration(
                        hintText: 'Search for your store address...',
                        hintStyle: TextStyle(color: Colors.brown.shade300, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: culinaeBrown),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _placeList = []);
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                      child: ListView.builder(
                        padding: EdgeInsets.zero, shrinkWrap: true, itemCount: _placeList.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: culinaeBrown),
                            title: Text(_placeList[index]['description']),
                            onTap: () => _selectPlaceAndNavigate(_placeList[index]['description']),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isManualMode = true;
                        _placeList = [];
                      });
                      FocusScope.of(context).unfocus();
                    },
                    icon: const Icon(Icons.touch_app, color: culinaeBrown),
                    label: const Text('Or pin-point manually on map', style: TextStyle(color: culinaeBrown, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.95),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 2,
                    ),
                  )
                ],
              ),
            )
          else
            Positioned(
              top: 20, left: 20, right: 20,
              child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Tap anywhere on the map to place your Store Pin!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: culinaeBrown)),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() => _isManualMode = false),
                          icon: const Icon(Icons.search, color: Colors.blueAccent),
                          label: const Text('Back to Search', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  )
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _storeLocation == null ? null : _confirmLocation,
        backgroundColor: _storeLocation == null ? Colors.grey : culinaeBrown,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        label: const Text('Confirm Location', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ============================================================================
// 2. CUSTOMER MAP TAB (Finding Stores & Searching)
// ============================================================================
class CustomerMapTab extends StatefulWidget {
  const CustomerMapTab({super.key});
  @override
  State<CustomerMapTab> createState() => _CustomerMapTabState();
}

class _CustomerMapTabState extends State<CustomerMapTab> {
  late GoogleMapController mapController;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _placeList = [];
  Set<Polyline> _polylines = {};
  LatLng? _currentPosition;
  LatLng? _selectedDestination;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _fetchStoreLocations();
  }

  void _fetchStoreLocations() {
    FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'owner').snapshots().listen((snapshot) {
      Set<Marker> storeMarkers = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['storeLocation'] != null) {
          final geo = data['storeLocation'] as GeoPoint;
          storeMarkers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(geo.latitude, geo.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                onTap: () => _showStorePopup(doc.id, data),
              )
          );
        }
      }
      setState(() {
        _markers.removeWhere((m) => m.markerId.value != 'searched_location');
        _markers.addAll(storeMarkers);
      });
    });
  }

  void _showStorePopup(String storeId, Map<String, dynamic> data) {
    final String profilePic = data['profilePicUrl']?.toString() ?? '';
    final String storeName = data['storeName']?.toString() ?? 'Unknown Store';
    final String storeType = data['storeType']?.toString() ?? 'Restaurant';

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                    radius: 30,
                    backgroundColor: culinaeBrown.withValues(alpha: 0.2),
                    backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                    child: profilePic.isEmpty ? const Icon(Icons.store, color: culinaeBrown) : null
                ),
                const SizedBox(height: 12),
                Text(storeName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: culinaeBrown)),
                Text(storeType, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: culinaeBrown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PublicStoreProfilePage(ownerId: storeId, storeName: storeName)));
                    },
                    child: const Text('VIEW STORE MENU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
    );
  }

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

    mapController.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 14.0));
  }

  void _getSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _placeList = []);
      return;
    }
    String request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleAPIKey&components=country:lk';
    var response = await http.get(Uri.parse(request));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);

      // 🚨 CATCH GOOGLE'S REJECTION LETTER
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        print("🚨 PLACES API ERROR: ${data['status']} - ${data['error_message']}");
      }

      setState(() => _placeList = data['predictions'] ?? []);
    } else {
      print("🚨 HTTP ERROR: ${response.statusCode}");
    }
  }

  Future<void> _selectPlaceAndNavigate(String address) async {
    setState(() {
      _searchController.text = address;
      _placeList = [];
      _polylines = {};
    });
    FocusScope.of(context).unfocus();

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _selectedDestination = LatLng(locations.first.latitude, locations.first.longitude);
          _markers.removeWhere((m) => m.markerId.value == 'searched_location');
          _markers.add(
            Marker(
              markerId: const MarkerId('searched_location'),
              position: _selectedDestination!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        });
        mapController.animateCamera(CameraUpdate.newLatLngZoom(_selectedDestination!, 14.0));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found.')));
    }
  }

  // --- UPDATED SAFETY NET FOR DIRECTIONS ---
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
        _polylines = {
          Polyline(polylineId: const PolylineId('route'), color: culinaeBrown, points: polylineCoordinates, width: 5),
        };
      });

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(min(_currentPosition!.latitude, _selectedDestination!.latitude), min(_currentPosition!.longitude, _selectedDestination!.longitude)),
        northeast: LatLng(max(_currentPosition!.latitude, _selectedDestination!.latitude), max(_currentPosition!.longitude, _selectedDestination!.longitude)),
      );
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } else {
      // 🚨 CATCH ROUTING ERRORS
      print("🚨 ROUTES API ERROR: ${result.errorMessage}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not route: ${result.errorMessage ?? "Check Google Cloud APIs/Billing."}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) => mapController = controller,
          style: mapStyle,
          initialCameraPosition: const CameraPosition(target: defaultLocation, zoom: 13.0),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        Positioned(
          top: 16, left: 16, right: 16,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(color: culinaeCream, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))]),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _getSuggestions(value),
                  decoration: InputDecoration(
                    hintText: 'Search for places, cities...',
                    hintStyle: TextStyle(color: Colors.brown.shade300, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: culinaeBrown),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _placeList = [];
                          _polylines = {};
                          _selectedDestination = null;
                          _markers.removeWhere((m) => m.markerId.value == 'searched_location');
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                  child: ListView.builder(
                    padding: EdgeInsets.zero, shrinkWrap: true, itemCount: _placeList.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: culinaeBrown),
                        title: Text(_placeList[index]['description']),
                        onTap: () => _selectPlaceAndNavigate(_placeList[index]['description']),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        if (_selectedDestination != null && _polylines.isEmpty)
          Positioned(
            bottom: 80, right: 16,
            child: FloatingActionButton.extended(
              onPressed: _getDirections,
              backgroundColor: culinaeBrown, foregroundColor: culinaeCream,
              icon: const Icon(Icons.directions),
              label: const Text("Directions", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton(
            backgroundColor: culinaeBrown, foregroundColor: culinaeCream,
            onPressed: _getUserLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. DELIVERY ROUTE MAP (For the Owner Dashboard)
// ============================================================================
class DeliveryRouteMap extends StatefulWidget {
  final GeoPoint customerLocation;
  const DeliveryRouteMap({super.key, required this.customerLocation});

  @override
  State<DeliveryRouteMap> createState() => _DeliveryRouteMapState();
}

class _DeliveryRouteMapState extends State<DeliveryRouteMap> {
  GoogleMapController? _mapController;
  LatLng? _storeLocation;
  late LatLng _customerLocation;

  @override
  void initState() {
    super.initState();
    _customerLocation = LatLng(widget.customerLocation.latitude, widget.customerLocation.longitude);
    _fetchStoreLocation();
  }

  Future<void> _fetchStoreLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final geo = doc.data()?['storeLocation'] as GeoPoint?;
      if (geo != null) {
        setState(() => _storeLocation = LatLng(geo.latitude, geo.longitude));
        _zoomToFitBoth();
      }
    }
  }

  void _zoomToFitBoth() {
    if (_mapController == null || _storeLocation == null) return;
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(min(_storeLocation!.latitude, _customerLocation.latitude), min(_storeLocation!.longitude, _customerLocation.longitude)),
      northeast: LatLng(max(_storeLocation!.latitude, _customerLocation.latitude), max(_storeLocation!.longitude, _customerLocation.longitude)),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {
      Marker(markerId: const MarkerId('customer'), position: _customerLocation, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), infoWindow: const InfoWindow(title: 'Customer Delivery')),
    };
    if (_storeLocation != null) {
      markers.add(Marker(markerId: const MarkerId('store'), position: _storeLocation!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), infoWindow: const InfoWindow(title: 'Your Store')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Route', style: TextStyle(color: culinaeBrown)), backgroundColor: culinaeCream, iconTheme: const IconThemeData(color: culinaeBrown)),
      body: GoogleMap(
        style: mapStyle,
        initialCameraPosition: CameraPosition(target: _customerLocation, zoom: 14),
        onMapCreated: (controller) {
          _mapController = controller;
          _zoomToFitBoth();
        },
        markers: markers,
        polylines: _storeLocation != null ? {
          Polyline(polylineId: const PolylineId('route'), points: [_storeLocation!, _customerLocation], color: Colors.blueAccent, width: 4, patterns: [PatternItem.dash(20), PatternItem.gap(10)])
        } : {},
      ),
    );
  }
}