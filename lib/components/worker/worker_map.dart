import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class WorkerMapScreen extends StatefulWidget {
  const WorkerMapScreen({super.key});

  @override
  State<WorkerMapScreen> createState() => _WorkerMapScreenState();
}

class _WorkerMapScreenState extends State<WorkerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  Set<Marker> _markers = {};
  
  // Default camera position (will be updated to user's location)
  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  CameraPosition _initialPosition = _kDefaultPosition;
  bool _hasLoadedInitialPosition = false;
  
  Map<String, dynamic> _taskData = {};
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchTasks();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied, we cannot request permissions.'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _initialPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14.4746,
        );
        _hasLoadedInitialPosition = true;
      });

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(_initialPosition));
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _fetchTasks() async {
    try {
      String? workerUid = _auth.currentUser?.uid;

      if (workerUid == null) {
        print('Worker UID not found.');
        setState(() {
          _isLoading = false;
        });
        return;
      }      // Get tasks assigned to worker by both assignedWorker and assignedWorkerId
      final QuerySnapshot snapshot1 = await _firestore
          .collection('waste_reports')
          .where('assignedWorker', isEqualTo: workerUid)
          .get();

      final QuerySnapshot snapshot2 = await _firestore
          .collection('waste_reports')
          .where('assignedWorkerId', isEqualTo: workerUid)
          .get();

      Set<String> processedIds = {};
      Set<Marker> markers = {};
        // Process all documents from both queries
      for (var doc in [...snapshot1.docs, ...snapshot2.docs]) {
        // Skip if already processed (to avoid duplicates)
        if (processedIds.contains(doc.id)) continue;
        processedIds.add(doc.id);

        final data = doc.data() as Map<String, dynamic>;
        String location = data['location'] ?? '';
        String status = data['status'] ?? '';
        String id = doc.id;
        String description = data['description'] ?? '';
        
        // Skip if no location data or not assigned/completed status
        if (location.isEmpty) continue;
        if (!['assigned', 'started', 'completed'].contains(status.toLowerCase())) continue;
        
        try {
          // Parse location as address and get coordinates 
          // In a real app, you should store coordinates directly in Firestore
          List<Location> locations = await locationFromAddress(location);
          if (locations.isNotEmpty) {
            Location loc = locations.first;
            BitmapDescriptor markerIcon;
            
            // Choose marker color based on status
            switch (status.toLowerCase()) {
              case 'assigned':
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
                break;
              case 'started': 
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
                break;
              case 'completed':
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
                break;
              default:
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            }
            
            // Create marker
            final marker = Marker(
              markerId: MarkerId(id),
              position: LatLng(loc.latitude, loc.longitude),
              icon: markerIcon,
              infoWindow: InfoWindow(
                title: "Task #${id.substring(0, 8)}",
                snippet: description,
                onTap: () {
                  _taskData = doc.data() as Map<String, dynamic>;
                  _taskData['id'] = doc.id;
                  _showTaskDetailsBottomSheet();
                },
              ),
            );
            
            markers.add(marker);
          }
        } catch (e) {
          print("Error geocoding location: $e");
        }
      }
      
      setState(() {
        _markers = markers;
        _isLoading = false;
      });
      
    } catch (e) {
      print("Error fetching tasks: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showTaskDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Task #${_taskData['id'].substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTaskDetailRow('Status', _taskData['status']?.toUpperCase() ?? 'UNKNOWN'),
                    _buildTaskDetailRow('Description', _taskData['description'] ?? 'No description'),
                    _buildTaskDetailRow('Location', _taskData['location'] ?? 'Unknown location'),
                    _buildTaskDetailRow('Waste Size', _taskData['wasteSize'] ?? 'Unknown size'),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Complete Details'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/task_details',
                            arguments: _createWasteReportFromMap(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.directions),
                        label: const Text('Get Directions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          // Navigation functionality could be added here
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Navigation functionality to be implemented')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  dynamic _createWasteReportFromMap() {
    DateTime timestamp = DateTime.now();
    if (_taskData['timestamp'] is Timestamp) {
      timestamp = (_taskData['timestamp'] as Timestamp).toDate();
    }
    
    return WasteReport(
      id: _taskData['id'] ?? '',
      description: _taskData['description'] ?? '',
      imageBase64: _taskData['imageBase64'] ?? '',
      location: _taskData['location'] ?? '',
      timestamp: timestamp,
      wasteSize: _taskData['wasteSize'] ?? '',
      status: _taskData['status'] ?? '',
    );
  }

  Widget _buildTaskDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchTasks();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Assigned', Colors.orange),
                    const SizedBox(height: 4),
                    _buildLegendItem('In Progress', Colors.blue),
                    const SizedBox(height: 4),
                    _buildLegendItem('Completed', Colors.green),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
    Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// WasteReport Model for passing data
class WasteReport {
  final String id;
  final String description;
  final String imageBase64;
  final String location;
  final DateTime timestamp;
  final String wasteSize;
  final String status;

  WasteReport({
    required this.id,
    required this.description,
    required this.imageBase64,
    required this.location,
    required this.timestamp,
    required this.wasteSize,
    required this.status,
  });
}