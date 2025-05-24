import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PolyGeofenceServic extends StatefulWidget {
  const PolyGeofenceServic({super.key});

  @override
  _PolyGeofenceServiceState createState() => _PolyGeofenceServiceState();
}

class _PolyGeofenceServiceState extends State<PolyGeofenceServic> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};  // Initialize _markers
  final Set<Circle> _reportCircles = {}; // Circles around waste reports (dynamic geofences)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  bool _showReportLocations = true;
  String? _errorMessage;
  
  // Marker icons for different statuses
  final BitmapDescriptor _pendingIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  final BitmapDescriptor _assignedIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  final BitmapDescriptor _inProgressIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  final BitmapDescriptor _completedIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);  @override
  void initState() {
    super.initState();
    _loadWasteReports();
  }

  // Load waste reports from Firestore
  Future<void> _loadWasteReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch waste reports from Firestore
      final QuerySnapshot snapshot = await _firestore.collection('waste_reports').get();
      
      // Clear existing circles and markers related to waste reports
      _reportCircles.clear();
      
      // Process each waste report
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? location = data['location'] as String?;
        
        // Skip if no location data
        if (location == null || location.isEmpty) continue;
        
        // Parse location string (format: "latitude, longitude")
        final List<String> coordinates = location.split(',');
        if (coordinates.length != 2) continue;
        
        double? latitude = double.tryParse(coordinates[0].trim());
        double? longitude = double.tryParse(coordinates[1].trim());
        
        // Skip if invalid coordinates
        if (latitude == null || longitude == null) continue;
        
        final LatLng position = LatLng(latitude, longitude);
        final String id = doc.id;
        final String status = data['status'] as String? ?? 'Pending';
        final String wasteType = data['wasteType'] as String? ?? 'Unknown';
        final String wasteSize = data['wasteSize'] as String? ?? 'Unknown';
        final int upvoteCount = data['upvoteCount'] as int? ?? 0;
        
        // Create circle around waste report (geofence)
        _reportCircles.add(
          Circle(
            circleId: CircleId('circle_$id'),
            center: position,
            radius: 50, // 50 meters radius
            fillColor: _getStatusColor(status).withOpacity(0.2),
            strokeColor: _getStatusColor(status),
            strokeWidth: 1,
          ),
        );
        
        // Create marker for waste report
        _markers.add(
          Marker(
            markerId: MarkerId('report_$id'),
            position: position,
            icon: _getStatusIcon(status),
            infoWindow: InfoWindow(
              title: '$wasteType Waste - $wasteSize',
              snippet: 'Status: $status | Upvotes: $upvoteCount',
            ),
          ),
        );
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading waste reports: $e';
      });
      debugPrint('Error loading waste reports: $e');
    }
  }
  
  // Get color based on waste report status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
      case 'started':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.red;
    }
  }
  
  // Get marker icon based on waste report status
  BitmapDescriptor _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _completedIcon;
      case 'in progress':
      case 'started':
        return _inProgressIcon;
      case 'assigned':
        return _assignedIcon;
      case 'pending':
      default:
        return _pendingIcon;
    }
  }
  // Initialize map controller with proper camera position
  Future<void> _initializeMapController() async {
    try {
      final controller = await _controller.future;
      // Default position (will be updated if waste reports are available)
      LatLng centerPosition = const LatLng(17.537872331494125, 78.38449590391323);
      
      // If we have waste reports, center on the first one
      if (_markers.isNotEmpty) {
        centerPosition = _markers.first.position;
      }
      
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: centerPosition,
          zoom: 15.0,
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
              "Waste Report Areas",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),           
          ],
        ),
        actions: [
          // Toggle waste report locations
          IconButton(
            icon: Icon(
              _showReportLocations ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showReportLocations = !_showReportLocations;
                if (!_showReportLocations) {
                  // Hide markers and circles
                  _reportCircles.clear();
                  _markers.clear();
                } else {
                  // Reload waste reports
                  _loadWasteReports();
                }
              });
            },
            tooltip: 'Toggle Waste Reports',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _loadWasteReports,
            tooltip: 'Refresh Reports',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: const CameraPosition(
              target: LatLng(17.537872331494125, 78.38449590391323),
              zoom: 15,
            ),
            markers: _markers,
            circles: _reportCircles,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _initializeMapController(); // Ensure this is called to animate camera
            },
          ),
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.green,
                ),
              ),
            ),
          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          // Status legend
          if (_showReportLocations)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Waste Report Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    _buildLegendItem(Colors.red, 'Pending'),
                    _buildLegendItem(Colors.orange, 'Assigned'),
                    _buildLegendItem(Colors.blue, 'In Progress'),
                    _buildLegendItem(Colors.green, 'Completed'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Helper method to build legend items
  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}