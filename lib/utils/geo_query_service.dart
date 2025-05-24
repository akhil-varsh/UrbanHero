import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class GeoQueryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Default search radius in meters
  static const double DEFAULT_RADIUS = 200;

  // Parse location string from Firestore (format: "latitude, longitude")
  LatLng? _parseLocationString(String locationString) {
    try {
      final parts = locationString.split(',');
      if (parts.length != 2) return null;
      
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      
      return LatLng(lat, lng);
    } catch (e) {
      print('Error parsing location string: $e');
      return null;
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Fetch nearby waste reports from Firestore
  Future<List<Map<String, dynamic>>> getNearbyReports(
    double latitude,
    double longitude, {
    double radiusInMeters = DEFAULT_RADIUS,
    String? excludeReportId,
  }) async {
    try {
      // Create a reference to the waste_reports collection
      final reportsRef = _firestore.collection('waste_reports');
      
      // We'll use a client-side filter since Firestore doesn't support geospatial queries directly
      final querySnapshot = await reportsRef
          .where('status', whereIn: ['Pending', 'Assigned', 'In Progress'])
          .orderBy('timestamp', descending: true)
          .get();

      // The current location as a LatLng object
      final currentLatLng = LatLng(latitude, longitude);
      
      // Filter reports that are within the radius
      final nearbyReports = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .where((report) {
            // Skip if this is the report we want to exclude
            if (excludeReportId != null && report['id'] == excludeReportId) {
              return false;
            }
            
            // Parse the location string
            final locationString = report['location'] as String?;
            if (locationString == null) return false;
            
            final reportLatLng = _parseLocationString(locationString);
            if (reportLatLng == null) return false;
            
            // Calculate the distance
            final distance = _calculateDistance(currentLatLng, reportLatLng);
            
            // Include if within radius
            return distance <= radiusInMeters;
          })
          .toList();
      
      return nearbyReports;
    } catch (e) {
      print('Error getting nearby reports: $e');
      return [];
    }
  }
}

// Simple LatLng class to store latitude and longitude
class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}
