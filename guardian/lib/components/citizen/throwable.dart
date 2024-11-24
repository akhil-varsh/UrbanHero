import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/components/citizen/home_screen.dart';
// Import the Cart widget

class PolyGeofenceServic extends StatefulWidget {
  @override
  _PolyGeofenceServiceState createState() => _PolyGeofenceServiceState();
}

class _PolyGeofenceServiceState extends State<PolyGeofenceServic> {
  Completer<GoogleMapController> _controller = Completer();
  Set<Polygon> _polygons = {}; // Initialize _polygons
  Set<Marker> _markers = {};  // Initialize _markers

  Future<void> _initializeMapController() async {
    final controller = await _controller.future;
    // You can perform any initialization here if needed
  }

  List<List<LatLng>> _polygonPointsList = [
    [
      LatLng(17.5455422, 78.3843941),
      LatLng(17.5457072, 78.3845504),
      LatLng(17.5458376, 78.3843116),
      LatLng(17.5455624, 78.3841638),
    ],
    [
      LatLng(17.5439512, 78.4024042),
      LatLng(17.5428687, 78.4048688),
      LatLng(17.5411894, 78.4040205),
      LatLng(17.5412566, 78.4021614),
    ],
    // Add more polygons if needed
  ];

  List<Polygon> _getPolygons() {
    return [
      Polygon(
        polygonId: PolygonId('geofence_area_0'),
        points: _polygonPointsList[0],
        strokeWidth: 2,
        strokeColor: Colors.red,
        fillColor: Colors.red.withOpacity(0.2),
      ),
      Polygon(
        polygonId: PolygonId('geofence_area_1'),
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
          markerId: MarkerId('dumpage_center'),
          position: LatLng(17.5455422, 78.3843941),
          infoWindow: InfoWindow(title: 'Dumpage'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: Offset(0.5, 0.8),
          zIndex: 10,
          rotation: 45,
          alpha: 0.8,
          flat: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              "Areas",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            // IconButton(
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
      body: FutureBuilder<void>(
        future: _initializeMapController(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: LatLng(17.537872331494125, 78.38449590391323),
                zoom: 15,
              ),
              markers: _markers,
              polygons: _polygons,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}