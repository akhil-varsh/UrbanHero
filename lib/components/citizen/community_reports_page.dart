// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:UrbanHero/utils/upvote_service.dart';
// import 'package:UrbanHero/utils/geo_query_service.dart';

// class CommunityReportsPage extends StatefulWidget {
//   const CommunityReportsPage({super.key});

//   @override
//   State<CommunityReportsPage> createState() => _CommunityReportsPageState();
// }

// class _CommunityReportsPageState extends State<CommunityReportsPage> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final UpvoteService _upvoteService = UpvoteService();
//   final GeoQueryService _geoQueryService = GeoQueryService();
  
//   bool _isLoading = false;
//   String? _errorMessage;
  
//   // Filter states
//   bool _showNearbyOnly = false;
//   String? _selectedStatus;
//   String? _selectedWasteType;
  
//   // User location
//   double? _userLatitude;
//   double? _userLongitude;
  
//   // List of all waste types and statuses (populated from data)
//   final List<String> _allWasteTypes = [];
//   final List<String> _allStatuses = ['Pending', 'Assigned', 'In Progress', 'Resolved'];
  
//   @override
//   void initState() {
//     super.initState();
//     _fetchWasteTypes();
//   }
  
//   Future<void> _fetchWasteTypes() async {
//   try {
//     final result = await _firestore.collection('waste_reports')
//         .get();
    
//     final wasteTypes = result.docs
//         .map((doc) => doc.data()['wasteType'] as String?)
//         .where((type) => type != null && type.isNotEmpty)
//         .cast<String>() // Cast after filtering out nulls
//         .toSet()
//         .toList();
    
//     setState(() {
//       _allWasteTypes.clear();
//       _allWasteTypes.addAll(wasteTypes);
//     });
//   } catch (e) {
//     print('Error fetching waste types: $e');
//   }
// }
  
//   Future<void> _getUserLocation() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
    
//     try {
//       // Check if we have permission
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           setState(() {
//             _errorMessage = 'Location permission denied';
//             _isLoading = false;
//           });
//           return;
//         }
//       }
      
//       if (permission == LocationPermission.deniedForever) {
//         setState(() {
//           _errorMessage = 'Location permissions permanently denied';
//           _isLoading = false;
//         });
//         return;
//       }
      
//       // Get current position
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high
//       );
      
//       setState(() {
//         _userLatitude = position.latitude;
//         _userLongitude = position.longitude;
//         _showNearbyOnly = true;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Error getting location: $e';
//         _isLoading = false;
//       });
//     }
//   }
  
//   void _resetFilters() {
//     setState(() {
//       _selectedStatus = null;
//       _selectedWasteType = null;
//       _showNearbyOnly = false;
//     });
//   }
  
//   Future<void> _upvoteReport(String reportId) async {
//     try {
//       final success = await _upvoteService.upvoteReport(reportId);
//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Report upvoted successfully!'),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('You have already upvoted this report.'),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Community Reports"),
//         backgroundColor: Colors.yellowAccent,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.filter_list),
//             onPressed: _showFilterBottomSheet,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Active filters display
//           if (_selectedStatus != null || _selectedWasteType != null || _showNearbyOnly)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               color: Colors.grey[200],
//               child: Row(
//                 children: [
//                   const Icon(Icons.filter_alt, size: 16),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: SingleChildScrollView(
//                       scrollDirection: Axis.horizontal,
//                       child: Row(
//                         children: [
//                           if (_showNearbyOnly)
//                             _buildFilterChip('Nearby'),
//                           if (_selectedStatus != null)
//                             _buildFilterChip('Status: $_selectedStatus'),
//                           if (_selectedWasteType != null)
//                             _buildFilterChip('Type: $_selectedWasteType'),
//                         ],
//                       ),
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: _resetFilters,
//                     child: const Text('Reset'),
//                   )
//                 ],
//               ),
//             ),
          
//           // Reports list
//           Expanded(
//             child: _buildReportsList(),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildFilterChip(String label) {
//     return Container(
//       margin: const EdgeInsets.only(right: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade100,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(
//           color: Colors.blue.shade800,
//           fontSize: 12,
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//     );
//   }
  
//   void _showFilterBottomSheet() {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             return Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Row(
//                     children: [
//                       Icon(Icons.filter_alt),
//                       SizedBox(width: 8),
//                       Text(
//                         'Filter Reports',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const Divider(),
                  
//                   // Location filter
//                   const Text(
//                     'Location',
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                   SwitchListTile(
//                     title: const Text('Show only nearby reports'),
//                     value: _showNearbyOnly,
//                     onChanged: (value) {
//                       setModalState(() {
//                         _showNearbyOnly = value;
//                       });
                      
//                       if (value && (_userLatitude == null || _userLongitude == null)) {
//                         // Need to get user location
//                         _getUserLocation().then((_) {
//                           // Update state outside of the modal
//                           setState(() {});
//                         });
//                       } else {
//                         // Update state outside of the modal
//                         setState(() {});
//                       }
//                     },
//                   ),
                  
//                   // Status filter
//                   const SizedBox(height: 8),
//                   const Text(
//                     'Status',
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                   Wrap(
//                     spacing: 8,
//                     children: [
//                       FilterChip(
//                         label: const Text('All'),
//                         selected: _selectedStatus == null,
//                         onSelected: (selected) {
//                           if (selected) {
//                             setModalState(() {
//                               _selectedStatus = null;
//                             });
//                             setState(() {});
//                           }
//                         },
//                       ),
//                       ..._allStatuses.map((status) {
//                         return FilterChip(
//                           label: Text(status),
//                           selected: _selectedStatus == status,
//                           onSelected: (selected) {
//                             setModalState(() {
//                               _selectedStatus = selected ? status : null;
//                             });
//                             setState(() {});
//                           },
//                         );
//                       }),
//                     ],
//                   ),
                  
//                   // Waste type filter
//                   const SizedBox(height: 8),
//                   const Text(
//                     'Waste Type',
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                   Wrap(
//                     spacing: 8,
//                     children: [
//                       FilterChip(
//                         label: const Text('All'),
//                         selected: _selectedWasteType == null,
//                         onSelected: (selected) {
//                           if (selected) {
//                             setModalState(() {
//                               _selectedWasteType = null;
//                             });
//                             setState(() {});
//                           }
//                         },
//                       ),
//                       ..._allWasteTypes.map((type) {
//                         return FilterChip(
//                           label: Text(type),
//                           selected: _selectedWasteType == type,
//                           onSelected: (selected) {
//                             setModalState(() {
//                               _selectedWasteType = selected ? type : null;
//                             });
//                             setState(() {});
//                           },
//                         );
//                       }),
//                     ],
//                   ),
                  
//                   // Apply button
//                   const SizedBox(height: 16),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         foregroundColor: Colors.white,
//                       ),
//                       onPressed: () {
//                         Navigator.pop(context);
//                         setState(() {});
//                       },
//                       child: const Text('Apply Filters'),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
  
//   Widget _buildReportsList() {
//     // If nearby only filter is active but we don't have location
//     if (_showNearbyOnly && (_userLatitude == null || _userLongitude == null)) {
//       if (_isLoading) {
//         return const Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text("Getting your location..."),
//             ],
//           ),
//         );
//       }
      
//       if (_errorMessage != null) {
//         return Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.location_off, size: 64, color: Colors.red),
//               const SizedBox(height: 16),
//               Text(
//                 _errorMessage!,
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: _getUserLocation,
//                 child: const Text("Try Again"),
//               ),
//             ],
//           ),
//         );
//       }
//     }
    
//     // Different query path based on filters
//     if (_showNearbyOnly && _userLatitude != null && _userLongitude != null) {
//       // For nearby reports, use the GeoQueryService
//       return FutureBuilder<List<Map<String, dynamic>>>(
//         future: _geoQueryService.getNearbyReports(
//           _userLatitude!,
//           _userLongitude!,
//           radiusInMeters: 2000, // 2km radius
//         ),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
          
//           if (snapshot.hasError) {
//             return Center(
//               child: Text("Error: ${snapshot.error}"),
//             );
//           }
          
//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(
//               child: Text("No nearby reports found."),
//             );
//           }
          
//           var reports = snapshot.data!;
          
//           // Apply additional filters
//           if (_selectedStatus != null) {
//             reports = reports.where((report) => 
//               report['status'] == _selectedStatus).toList();
//           }
          
//           if (_selectedWasteType != null) {
//             reports = reports.where((report) => 
//               report['wasteType'] == _selectedWasteType).toList();
//           }
          
//           if (reports.isEmpty) {
//             return const Center(
//               child: Text("No reports match your filters."),
//             );
//           }
          
//           return _buildReportsListView(reports);
//         },
//       );
//     } else {
//       // For regular filtering, use Firestore queries
//       return StreamBuilder<QuerySnapshot>(
//         stream: _buildFilteredQuery().snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
          
//           if (snapshot.hasError) {
//             return Center(
//               child: Text("Error: ${snapshot.error}"),
//             );
//           }
          
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(
//               child: Text("No reports found."),
//             );
//           }
          
//           // Convert to the same format as the nearby reports
//           final reports = snapshot.data!.docs.map((doc) {
//             return {
//               'id': doc.id,
//               ...doc.data() as Map<String, dynamic>,
//             };
//           }).toList();
          
//           return _buildReportsListView(reports);
//         },
//       );
//     }
//   }
  
//   Query<Map<String, dynamic>> _buildFilteredQuery() {
//     Query<Map<String, dynamic>> query = _firestore.collection('waste_reports');
    
//     // Apply status filter
//     if (_selectedStatus != null) {
//       query = query.where('status', isEqualTo: _selectedStatus);
//     }
    
//     // Apply waste type filter
//     if (_selectedWasteType != null) {
//       query = query.where('wasteType', isEqualTo: _selectedWasteType);
//     }
    
//     // Sort by upvote count (high to low) and then by timestamp (new to old)
//     query = query.orderBy('upvoteCount', descending: true)
//                 .orderBy('timestamp', descending: true);
    
//     return query;
//   }
  
//   Widget _buildReportsListView(List<Map<String, dynamic>> reports) {
//     return ListView.builder(
//       itemCount: reports.length,
//       itemBuilder: (context, index) {
//         final report = reports[index];
//         final reportId = report['id'] as String;
//         final status = report['status'] as String? ?? 'Pending';
//         final wasteType = report['wasteType'] as String? ?? 'Unknown';
//         final imageBase64 = report['imageBase64'] as String?;
//         final description = report['description'] as String? ?? 'No description';
//         final timestamp = report['timestamp'] as Timestamp?;
//         final upvoteCount = report['upvoteCount'] as int? ?? 0;
//         final location = report['formattedAddress'] as String? ?? 
//                         report['location'] as String? ?? 'Unknown location';
        
//         Color statusColor;
//         switch (status) {
//           case 'Resolved':
//             statusColor = Colors.green;
//             break;
//           case 'In Progress':
//             statusColor = Colors.orange;
//             break;
//           case 'Assigned':
//             statusColor = Colors.blue;
//             break;
//           default:
//             statusColor = Colors.red;
//         }
        
//         return Card(
//           margin: const EdgeInsets.all(8.0),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Status badge
//               Align(
//                 alignment: Alignment.topRight,
//                 child: Container(
//                   margin: const EdgeInsets.only(right: 12, top: 12),
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: statusColor,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     status,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//               ),
              
//               // Image Section
//               if (imageBase64 != null && imageBase64.isNotEmpty)
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(10),
//                   child: Image.memory(
//                     base64Decode(imageBase64),
//                     width: double.infinity,
//                     height: 180,
//                     fit: BoxFit.cover,
//                   ),
//                 )
//               else
//                 Container(
//                   width: double.infinity,
//                   height: 180,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
//                 ),
              
//               Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Waste type and upvote count
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Chip(
//                           label: Text(
//                             wasteType,
//                             style: const TextStyle(color: Colors.white),
//                           ),
//                           backgroundColor: Colors.blue.shade700,
//                         ),
                        
//                         // Upvote button and counter
//                         Row(
//                           children: [
//                             Text(
//                               '$upvoteCount',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: upvoteCount > 0 ? Colors.green.shade700 : Colors.grey.shade600,
//                               ),
//                             ),
//                             const SizedBox(width: 4),
                            
//                             // Upvote button
//                             StreamBuilder<bool>(
//                               stream: Stream.fromFuture(
//                                 _upvoteService.hasUserUpvoted(reportId),
//                               ),
//                               builder: (context, snapshot) {
//                                 final hasUpvoted = snapshot.data ?? false;
                                
//                                 return IconButton(
//                                   icon: Icon(
//                                     hasUpvoted 
//                                         ? Icons.thumb_up
//                                         : Icons.thumb_up_outlined,
//                                     color: hasUpvoted 
//                                         ? Colors.green
//                                         : Colors.grey.shade700,
//                                   ),
//                                   onPressed: () => _upvoteReport(reportId),
//                                 );
//                               },
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
                    
//                     const SizedBox(height: 8),
                    
//                     // Description
//                     Text(
//                       description,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
                    
//                     const SizedBox(height: 8),
                    
//                     // Location with icon
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, size: 16, color: Colors.grey),
//                         const SizedBox(width: 4),
//                         Expanded(
//                           child: Text(
//                             location,
//                             style: TextStyle(color: Colors.grey.shade700),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       ],
//                     ),
                    
//                     const SizedBox(height: 4),
                    
//                     // Date
//                     if (timestamp != null)
//                       Text(
//                         "Reported on: ${timestamp.toDate().toString().substring(0, 16)}",
//                         style: const TextStyle(fontSize: 12, color: Colors.grey),
//                       ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
