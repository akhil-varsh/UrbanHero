import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart' as cluster_manager_lib; // REMOVED
import 'package:UrbanHero/components/manager/reported_issues.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _googleMapControllerCompleter = Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  static const LatLng _initialPosition = LatLng(17.3850, 78.4867); // Hyderabad

  Set<Marker> _firestoreMarkers = {}; // Markers from Firestore
  final Set<Marker> _searchMarkers = {}; // Markers from search results
  Set<Marker> _allMarkers = {}; // Combined set of markers for the map

  BitmapDescriptor _defaultWasteIcon = BitmapDescriptor.defaultMarker;
  // late cluster_manager_lib.ClusterManager _clusterManager; // REMOVED

  @override
  void initState() {
    super.initState();
    // _clusterManager = _initClusterManager(); // REMOVED
    _loadDefaultMarkerIcon();
    _updateAllMarkers(); // Initialize with empty or default markers
  }

  // REMOVED _initClusterManager method
  // REMOVED _updateMarkersFromClusterManager method
  // REMOVED _markerBuilder method (logic will be integrated into _processFirestoreDocs)

  void _updateAllMarkers() {
    if (mounted) {
      setState(() {
        _allMarkers = {..._firestoreMarkers, ..._searchMarkers};
      });
    }
  }

  void _showIssueDetailsDialog(DocumentSnapshot doc) { // MODIFIED to take DocumentSnapshot
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    String? locString = data['location'] as String?;
    LatLng position = const LatLng(0,0);
    if (locString != null && locString.isNotEmpty) {
      List<String> latLngParts = locString.split(',');
      if (latLngParts.length == 2) {
        double? lat = double.tryParse(latLngParts[0].trim());
        double? lng = double.tryParse(latLngParts[1].trim());
        if (lat != null && lng != null) {
          position = LatLng(lat, lng);
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Issue: ${data['wasteSize'] ?? 'N/A'}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('ID: ${doc.id}'),
                Text('Status: ${data['status'] ?? 'Unknown'}'),
                Text('Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
                if (data['assignedWorkerName'] != null) Text('Assigned: ${data['assignedWorkerName']}'),
                if (data['description'] != null) Text('Description: ${data['description']}'),
                if (data['timestamp'] != null) Text('Reported: ${(data['timestamp'] as Timestamp).toDate().toString().split('.')[0]}'),
                const SizedBox(height: 10),
                if (data['imageBase64'] != null && (data['imageBase64'] as String).isNotEmpty)
                  _buildDialogImageWidget(data['imageBase64'] as String)
                else
                  const Text('No image available.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogImageWidget(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, height: 150, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 50));
    } else {
      try {
        final decodedBytes = base64Decode(imageUrl);
        return Image.memory(decodedBytes, height: 150, fit: BoxFit.cover);
      } catch (e) {
        return const Icon(Icons.broken_image, size: 50);
      }
    }
  }

  Future<void> _loadDefaultMarkerIcon() async {
    const Size iconSize = Size(80, 80);
    try {
      final ByteData assetByteData = await rootBundle.load('images/waste.jpeg');
      final Uint8List assetBytes = assetByteData.buffer.asUint8List();
      final ui.Codec assetCodec = await ui.instantiateImageCodec(assetBytes);
      final ui.FrameInfo assetFrameInfo = await assetCodec.getNextFrame();
      final ui.Image originalAssetImage = assetFrameInfo.image;
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..isAntiAlias = true;
      final double radius = iconSize.width / 2;
      final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius));
      canvas.clipPath(clipPath);
      final double imageWidth = originalAssetImage.width.toDouble();
      final double imageHeight = originalAssetImage.height.toDouble();
      final double S = math.min(imageWidth, imageHeight);
      final Rect src = Rect.fromLTWH((imageWidth - S) / 2, (imageHeight - S) / 2, S, S);
      final Rect dst = Rect.fromLTWH(0, 0, iconSize.width, iconSize.height);
      canvas.drawImageRect(originalAssetImage, src, dst, paint);
      final ui.Image circularImage = await pictureRecorder.endRecording().toImage(iconSize.width.toInt(), iconSize.height.toInt());
      final ByteData? finalByteData = await circularImage.toByteData(format: ui.ImageByteFormat.png);
      if (finalByteData != null) {
        if (mounted) {
          setState(() {
            _defaultWasteIcon = BitmapDescriptor.fromBytes(finalByteData.buffer.asUint8List());
          });
        }
      } else { throw Exception("Failed to generate circular byte data for default icon"); }
    } catch (e) {
      print("Error loading default waste icon as circular: $e");
      if (mounted) {
        setState(() { _defaultWasteIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed); });
      }
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String? imageBase64, {String? status, Size size = const Size(80, 80)}) async {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        Uint8List imageBytes = base64Decode(imageBase64);
        final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image originalImage = frameInfo.image;
        final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(pictureRecorder);
        final Paint paint = Paint()..isAntiAlias = true;
        final double radius = size.width / 2;
        final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius));
        canvas.clipPath(clipPath);
        final double imageWidth = originalImage.width.toDouble();
        final double imageHeight = originalImage.height.toDouble();
        final double S = math.min(imageWidth, imageHeight);
        final Rect src = Rect.fromLTWH((imageWidth - S) / 2, (imageHeight - S) / 2, S, S);
        final Rect dst = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawImageRect(originalImage, src, dst, paint);
        final ui.Image circularImage = await pictureRecorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
        final ByteData? byteData = await circularImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) { return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List()); }
      } catch (e) { print('Error decoding/resizing/clipping imageBase64 for marker: $e'); }
    }
    return _defaultWasteIcon;
  }

  Future<void> _processFirestoreDocs(List<QueryDocumentSnapshot> docs) async { // MODIFIED to be async
    Set<Marker> newFirestoreMarkers = {};
    for (var doc in docs) {
      Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
      String? locString = data['location'] as String?;
      LatLng position = const LatLng(0,0);

      if (locString != null && locString.isNotEmpty) {
        List<String> latLngParts = locString.split(',');
        if (latLngParts.length == 2) {
          double? lat = double.tryParse(latLngParts[0].trim());
          double? lng = double.tryParse(latLngParts[1].trim());
          if (lat != null && lng != null) {
            position = LatLng(lat, lng);
          }
        }
      }

      // Filter out invalid locations
      if (position.latitude == 0 && position.longitude == 0 && locString != "0,0") { // Be more specific if "0,0" is a valid input for some reason
          print("Skipping document ${doc.id} due to invalid parsed location: $locString");
          continue;
      }

      BitmapDescriptor icon = await _getMarkerIcon(data['imageBase64'] as String?, status: data['status'] as String?);

      newFirestoreMarkers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(
            title: 'Waste: ${data['wasteSize'] ?? 'N/A'} (Status: ${data['status'] ?? 'Unknown'})',
            snippet: 'Assigned: ${data['assignedWorkerName'] ?? 'N/A'}\\nTap for details.',
            onTap: () => _showIssueDetailsDialog(doc),
          ),
        ),
      );
    }
    if (mounted) {
      setState(() {
        _firestoreMarkers = newFirestoreMarkers;
        _updateAllMarkers();
      });
    }
  }

  Future<void> _goToPlace(LatLng position, {double zoom = 14.0}) async {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: position, zoom: zoom)));
    }
  }

  Future<void> _onSearch() async {
    final String query = _searchController.text;
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a search query')));
      return;
    }
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final Location firstLocation = locations.first;
        final LatLng position = LatLng(firstLocation.latitude, firstLocation.longitude);
        _goToPlace(position);
        if (mounted) {
          setState(() {
            _searchMarkers.clear();
            final Marker searchMarker = Marker(
              markerId: const MarkerId('search_result'),
              position: position,
              infoWindow: InfoWindow(title: query, snippet: 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            );
            _searchMarkers.add(searchMarker);
            _updateAllMarkers(); // Update combined markers
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found')));
        if (mounted) { setState(() { _searchMarkers.clear(); _updateAllMarkers(); }); }
      }
    } catch (e) {
      print('Error searching for location: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error finding location. Please try again.')));
      if (mounted) { setState(() { _searchMarkers.clear(); _updateAllMarkers(); }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Added background color
      appBar: AppBar(
        title: const Text(
          'Waste Hotspots Map',
          style: TextStyle( // Added text style
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700, // Changed background color
        elevation: 0, // Changed elevation
        iconTheme: const IconThemeData(color: Colors.white), // Added icon theme for back button
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Adjusted padding
            child: Container( // Added Container for search bar styling
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for a location...',
                  prefixIcon: Icon(Icons.search, color: Colors.green.shade700), // Changed icon color
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (mounted) {
                            setState(() {
                              _searchMarkers.clear();
                              _updateAllMarkers();
                            });
                          }
                        })
                    : null,
                  border: InputBorder.none, // Removed border from TextField itself
                  filled: false, // No fill for TextField, container handles background
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                ),
                onSubmitted: (value) => _onSearch(),
                onChanged: (value) { setState(() {}); },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('waste_reports').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  print('Error fetching waste reports: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting && _firestoreMarkers.isEmpty) {
                    return Center(child: CircularProgressIndicator(color: Colors.green.shade700)); // Changed color
                }
                if (snapshot.hasData) {
                  // Important: Call _processFirestoreDocs without await in builder if it involves setState
                  // to avoid issues. Or, ensure it's handled correctly if async.
                  // For simplicity here, assuming _processFirestoreDocs updates state internally.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                     if (mounted) _processFirestoreDocs(snapshot.data!.docs);
                  });
                }
                return GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: const CameraPosition(target: _initialPosition, zoom: 12),
                  markers: _allMarkers, // Use the combined set of markers
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller; 
                    if (!_googleMapControllerCompleter.isCompleted) {
                       _googleMapControllerCompleter.complete(controller);
                    }
                    // _clusterManager.setMapId(controller.mapId); // REMOVED
                  },
                  // onCameraMove: (CameraPosition position) => _clusterManager.onCameraMove(position), // REMOVED
                  // onCameraIdle: _clusterManager.updateMap, // REMOVED
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.08), // Padding for FAB
                  myLocationButtonEnabled: true, // Enable my location button
                  myLocationEnabled: true, // Show my location dot (requires permission)
                  zoomControlsEnabled: false, // Disable default zoom controls, can add custom if needed
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportedIssues()),
          );
        },
        label: const Text('View All Reports', style: TextStyle(color: Colors.white)), // Ensured text color
        icon: const Icon(Icons.list_alt_outlined, color: Colors.white), // Ensured icon color
        backgroundColor: Colors.green.shade700, // Changed background color
        elevation: 6.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
