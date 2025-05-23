import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Import the Cart widget

class PolyGeofenceServic extends StatefulWidget {
  const PolyGeofenceServic({super.key});

  @override
  _PolyGeofenceServiceState createState() => _PolyGeofenceServiceState();
}

class _PolyGeofenceServiceState extends State<PolyGeofenceServic> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Polygon> _polygons = {}; // Initialize _polygons
  final Set<Marker> _markers = {};  // Initialize _markers

  final List<List<LatLng>> _polygonPointsList = [
    [
      const LatLng(17.5455422, 78.3843941),
      const LatLng(17.5457072, 78.3845504),
      const LatLng(17.5458376, 78.3843116),
      const LatLng(17.5455624, 78.3841638),
    ],
    [
      const LatLng(17.5439512, 78.4024042),
      const LatLng(17.5428687, 78.4048688),
      const LatLng(17.5411894, 78.4040205),
      const LatLng(17.5412566, 78.4021614),
    ],
    // Add more polygons if needed
  ];

  List<Polygon> _getPolygons() {
    return [
      Polygon(
        polygonId: const PolygonId('geofence_area_0'),
        points: _polygonPointsList[0],
        strokeWidth: 2,
        strokeColor: Colors.red,
        fillColor: Colors.red.withOpacity(0.2),
      ),
      Polygon(
        polygonId: const PolygonId('geofence_area_1'),
        points: _polygonPointsList[1],
        strokeWidth: 2,
        strokeColor: Colors.red,
        fillColor: Colors.red.withOpacity(0.2),
      ),
      // Add more polygons with different colors if needed
    ];
  }

  @override
  void initState() {
    super.initState();
    _initPolygons();
    _initMarker();
  }

  void _initPolygons() {
    setState(() {
      _polygons.addAll(_getPolygons());
    });
  }

  void _initMarker() {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('dumpage_center'),
          position: const LatLng(17.5455422, 78.3843941),
          infoWindow: const InfoWindow(title: 'Dumpage'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.8),
          zIndex: 10,
          rotation: 45,
          alpha: 0.8,
          flat: true,
        ),
      );
    });
  }

  // Initialize map controller with proper camera position
  Future<void> _initializeMapController() async {
    try {
      final controller = await _controller.future;
      // Move camera to first marker/polygon for better user orientation
      controller.animateCamera(CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(17.5455422, 78.3843941), // Center on first marker
          zoom: 16.0,
          tilt: 45.0,
        ),
      ));
    } catch (e) {
      debugPrint('Error initializing map controller: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              "Areas",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),            // IconButton(
            //   icon: Icon(
            //     Icons.emergency_outlined,
            //     color: Colors.redAccent,
            //     size: 30.0,
            //   ),
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => Cart()),
            //     );
            //   },
            // ),
          ],
        ),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: const CameraPosition(
          target: LatLng(17.537872331494125, 78.38449590391323),
          zoom: 15,
        ),
        markers: _markers,
        polygons: _polygons,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
          _initializeMapController(); // Ensure this is called to animate camera
        },
      ),
    );
  }
}