import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:UrbanHero/utils/upvote_service.dart';

class TrackIssuesPage extends StatefulWidget {
  const TrackIssuesPage({super.key});

  @override
  State<TrackIssuesPage> createState() => _TrackIssuesPageState();
}

class _TrackIssuesPageState extends State<TrackIssuesPage> with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UpvoteService _upvoteService = UpvoteService();
  
  // Cache for user upvote status to avoid repeated Firestore queries
  final Map<String, bool> _userUpvoteCache = {};
  // Cache for decoded images
  final Map<String, Uint8List> _imageCache = {};
  
  // Pagination variables
  int _limit = 10;
  bool _hasMoreData = true;
  bool _isLoading = false;
  List<DocumentSnapshot> _allIssues = [];
  DocumentSnapshot? _lastDocument;
  
  // Filter variables
  String _sortBy = 'timestamp'; // Default sort by newest
  bool _sortDescending = true; // Default descending order (newest first)
  String? _filterByStatus; // Filter by status (null means all)
  String? _filterByWasteType; // Filter by waste type (null means all)
  String _searchQuery = ''; // New: For search text
  String? _selectedWasteSize; // New: For waste size filter
  DateTime? _selectedDate; // New: For date filter

  // Lists for filter dropdowns
  final List<String> _statusTypes = ['started','assigned' 'in Progress', 'completed'];
  final List<String> _wasteTypes = ['Plastic', 'Paper', 'Glass', 'Metal', 'Organic', 'Electronic', 'Other'];
  final List<String> _wasteSizes = ['Small', 'Medium', 'Large', 'Extra Large'];

  @override
  bool get wantKeepAlive => true; // Keep the state alive when scrolling
  
  // Method to upvote an issue
  Future<void> _upvoteIssue(BuildContext context, String reportId) async {
    try {
      final success = await _upvoteService.upvoteReport(reportId);
      
      if (success) {
        // Update the cache when upvote is successful
        setState(() {
          _userUpvoteCache[reportId] = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report upvoted successfully!'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already upvoted this report.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  // Show details dialog for a waste report
  void _showDetailsDialog(BuildContext context, Map<String, dynamic> issueData, String reportId) {
    final upvoteCount = issueData['upvoteCount'] as int? ?? 0;
    final reportStatus = issueData['status'] as String? ?? 'Pending';
    final wasteType = issueData['wasteType'] as String? ?? 'Unknown';
    final wasteSize = issueData['wasteSize'] as String? ?? 'Unknown';
    final location = issueData['location'] as String? ?? 'Unknown';
    final timestamp = issueData['timestamp'] as Timestamp?;
    final startedAt = issueData['startedAt'] as Timestamp?;
    final completedAt = issueData['completedAt'] as Timestamp?;
    final assignedWorkerName = issueData['assignedWorkerName'] as String? ?? 'Not assigned';
    
    // Process image in advance for better performance
    Uint8List? imageBytes;
    if (issueData.containsKey('imageBase64') && 
        issueData['imageBase64'] is String && 
        (issueData['imageBase64'] as String).isNotEmpty) {
      
      final imageBase64 = issueData['imageBase64'] as String;
      
      // Check if image is already in cache
      if (_imageCache.containsKey(reportId)) {
        imageBytes = _imageCache[reportId];
      } else {
        // Decode image and add to cache
        try {
          imageBytes = base64Decode(imageBase64);
          _imageCache[reportId] = imageBytes;
        } catch (e) {
          print('Error decoding image for report $reportId: $e');
        }
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.report_problem,
              color: _getStatusColor(reportStatus),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('Waste Report Details'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Section - Increased size
                if (imageBytes != null)
                  Container(
                    width: double.infinity,
                    height: 250, // Increased from 150
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 250,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Status with indicator
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(reportStatus),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        reportStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '$upvoteCount upvotes', 
                        style: TextStyle(
                          color: upvoteCount > 0 ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Basic information
                _detailRow('Waste Type', wasteType),
                _detailRow('Waste Size', wasteSize),
                _detailRow('Location', location),
                
                const Divider(height: 24),
                
                // Timeline information
                _detailRow('Reported On', timestamp != null 
                  ? _formatTimestamp(timestamp) 
                  : 'Unknown'),
                  
                if (startedAt != null)
                  _detailRow('Started At', _formatTimestamp(startedAt)),
                  
                if (completedAt != null)
                  _detailRow('Completed At', _formatTimestamp(completedAt)),
                
                if (assignedWorkerName != 'Not assigned')
                  _detailRow('Assigned Worker', assignedWorkerName),
                
                // Description if available
                if (issueData['description'] != null && (issueData['description'] as String).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Description:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(issueData['description'] as String),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _upvoteIssue(context, reportId);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.thumb_up),
            label: const Text('Upvote'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper for creating detail rows in the dialog
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
  
  // Format timestamp to readable date and time
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  // Get color based on status
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

  @override
  void initState() {
    super.initState();
    // Load initial data
    _getIssues();
  }
  
  @override
  void dispose() {
    // Clear caches
    _userUpvoteCache.clear();
    _imageCache.clear();
    super.dispose();
  }

  // New method to reset filters and fetch issues
  void _resetAndFetchIssues() {
    // Clearing image/upvote cache might be too aggressive if not strictly needed for filtering,
    // but can prevent stale data if issue details change based on filters.
    // _userUpvoteCache.clear(); 
    // _imageCache.clear();

    setState(() {
      _allIssues = [];
      _lastDocument = null;
      _hasMoreData = true;
      // _isLoading will be handled by _getIssues
    });
    _getIssues();
  }

  // Load initial set of issues
  Future<void> _getIssues() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Query query = _firestore.collection('waste_reports');

      // Apply filters
      if (_filterByStatus != null) {
        query = query.where('status', isEqualTo: _filterByStatus);
      }
      if (_filterByWasteType != null) {
        query = query.where('wasteType', isEqualTo: _filterByWasteType);
      }
      if (_selectedWasteSize != null) {
        query = query.where('wasteSize', isEqualTo: _selectedWasteSize);
      }
      if (_selectedDate != null) {
        // Firestore timestamp queries require a range. 
        // For a single day, query from start of day to end of day.
        Timestamp startOfDay = Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0));
        Timestamp endOfDay = Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59));
        query = query.where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                     .where('timestamp', isLessThanOrEqualTo: endOfDay);
      }

      // Apply sorting
      query = query.orderBy(_sortBy, descending: _sortDescending);
      
      // Apply limit for pagination
      query = query.limit(_limit);
      
      QuerySnapshot querySnapshot = await query.get();
          
      if (querySnapshot.docs.isNotEmpty) {
        _allIssues = querySnapshot.docs;
        _lastDocument = querySnapshot.docs.last;
        
        // Check if we have more data to load
        if (querySnapshot.docs.length < _limit) {
          _hasMoreData = false;
        }
        
        // Prefetch upvote status after loading issues
        _prefetchUpvoteStatus();
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      print('Error getting issues: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Load more issues when user scrolls to bottom
  Future<void> _loadMoreIssues() async {
    if (_isLoading || !_hasMoreData || _lastDocument == null) return;
      setState(() {
      _isLoading = true;
    });
    
    try {
      Query query = _firestore.collection('waste_reports');

      // Apply filters (must be consistent with _getIssues)
      if (_filterByStatus != null) {
        query = query.where('status', isEqualTo: _filterByStatus);
      }
      if (_filterByWasteType != null) {
        query = query.where('wasteType', isEqualTo: _filterByWasteType);
      }
      if (_selectedWasteSize != null) {
        query = query.where('wasteSize', isEqualTo: _selectedWasteSize);
      }
      if (_selectedDate != null) {
        Timestamp startOfDay = Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0));
        Timestamp endOfDay = Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59));
        query = query.where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                     .where('timestamp', isLessThanOrEqualTo: endOfDay);
      }

      // Apply sorting
      query = query.orderBy(_sortBy, descending: _sortDescending);

      // Apply pagination
      query = query.startAfterDocument(_lastDocument!).limit(_limit);

      QuerySnapshot querySnapshot = await query.get();
          
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _allIssues.addAll(querySnapshot.docs);
        
        // Check if we have more data to load
        if (querySnapshot.docs.length < _limit) {
          _hasMoreData = false;
        }
        
        // Prefetch upvote status for new issues
        _prefetchUpvoteStatus();
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      print('Error loading more issues: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Prefetch upvote status for all reports once
  Future<void> _prefetchUpvoteStatus() async {
    try {
      // Only prefetch for visible reports to save resources
      for (var doc in _allIssues) {
        final reportId = doc.id;
        if (!_userUpvoteCache.containsKey(reportId)) {
          final hasUpvoted = await _upvoteService.hasUserUpvoted(reportId);
          if (mounted) {
            _userUpvoteCache[reportId] = hasUpvoted;
          }
        }
      }
      if (mounted) {
        setState(() {}); // Refresh UI after prefetching
      }
    } catch (e) {
      print('Error prefetching upvote status: $e');
    }
  }
    // Debug method to check Firestore collection
  Future<void> _debugFirestore(BuildContext context) async {
    try {
      // Fetch all documents from waste_reports collection without any filtering
      final QuerySnapshot snapshot = await _firestore.collection('waste_reports').get();
      
      String message;
      if (snapshot.docs.isEmpty) {
        message = 'No documents found in waste_reports collection.';
      } else {
        message = '${snapshot.docs.length} documents found in waste_reports collection.';
        // Print document IDs to console for debugging
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final upvoteCount = data['upvoteCount'] as int? ?? 0;
          print('Document ID: ${doc.id}, Upvotes: $upvoteCount');
        }
      }
      
      // Show debug info in a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing Firestore: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  // New getter for issues to be displayed, applying client-side search
  List<DocumentSnapshot> get _displayedIssues {
    if (_searchQuery.isEmpty) {
      return _allIssues;
    }
    final query = _searchQuery.toLowerCase();
    return _allIssues.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String reportId = doc.id.toLowerCase();
      final String wasteType = (data['wasteType'] as String? ?? '').toLowerCase();
      // Assuming 'location' is the field for location data. Adjust if it's e.g. 'address'
      final String location = (data['location'] as String? ?? '').toLowerCase(); 
      final String status = (data['status'] as String? ?? '').toLowerCase();
      final String description = (data['description'] as String? ?? '').toLowerCase();
      final String wasteSize = (data['wasteSize'] as String? ?? '').toLowerCase();

      return reportId.contains(query) ||
             wasteType.contains(query) ||
             location.contains(query) ||
             status.contains(query) ||
             description.contains(query) ||
             wasteSize.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final displayedIssues = _displayedIssues; // Use the getter for search

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Waste Reports"),
        backgroundColor: Colors.yellowAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _debugFirestore(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 10), // Adjust height as needed
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by ID, type, location, status...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  // Client-side search, no need to call _getIssues here
                  // If server-side search is desired, _resetAndFetchIssues() would be called.
                });
              },
            ),
          ),
        ),
      ),
      body: _isLoading && displayedIssues.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : displayedIssues.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "No waste reports found.",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "All reports will appear here when available.",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Clear cache and reload
                    _allIssues.clear();
                    _lastDocument = null;
                    _hasMoreData = true;
                    _userUpvoteCache.clear();
                    _imageCache.clear();
                    // Reset search query as well on pull-to-refresh
                    setState(() {
                      _searchQuery = '';
                    });
                    await _getIssues();
                  },
                  child: ListView.builder(
                    key: const PageStorageKey('waste-reports-list'),
                    itemCount: displayedIssues.length + (_hasMoreData && _searchQuery.isEmpty ? 1 : 0), // Adjust itemCount for search
                    padding: const EdgeInsets.all(8.0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the bottom while loading more
                      if (_searchQuery.isEmpty && index == displayedIssues.length) {
                        // Trigger load more only once
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _loadMoreIssues();
                        });
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      // Get issue data
                      var issueData = displayedIssues[index].data() as Map<String, dynamic>;
                      final reportId = displayedIssues[index].id;
                      final upvoteCount = issueData['upvoteCount'] as int? ?? 0;
                      final bool isHighPriority = upvoteCount >= 5;
                      final status = issueData['status'] as String? ?? 'Pending';
                      final wasteType = issueData['wasteType'] as String? ?? 'Unknown';
                      final wasteSize = issueData['wasteSize'] as String? ?? 'Unknown';
                      final timestamp = issueData['timestamp'] as Timestamp?;
                      final location = issueData['location'] as String? ?? 'Unknown';
                      
                      // Prefetch and cache image for better performance
                      if (issueData.containsKey('imageBase64') && 
                          issueData['imageBase64'] is String && 
                          (issueData['imageBase64'] as String).isNotEmpty &&
                          !_imageCache.containsKey(reportId)) {
                        try {
                          final imageBase64 = issueData['imageBase64'] as String;
                          _imageCache[reportId] = base64Decode(imageBase64);
                        } catch (e) {
                          print('Error decoding image for report $reportId: $e');
                        }
                      }
                      
                      // Get upvote status from cache if available
                      bool hasUpvoted = _userUpvoteCache[reportId] ?? false;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: isHighPriority ? 8 : 3,
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Report header with status badge
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: _getStatusColor(status)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            wasteType,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: _getStatusColor(status),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.thumb_up,
                                              size: 16,
                                              color: upvoteCount > 0 ? Colors.green : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$upvoteCount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: upvoteCount > 0 ? Colors.green : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Report content
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Display image with error handling - Increased size
                                        if (_imageCache.containsKey(reportId))
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 16),
                                            height: 200, // Increased from 80
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.memory(
                                                _imageCache[reportId]!,
                                                height: 200,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 200,
                                                    color: Colors.grey.shade200,
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.broken_image, 
                                                        color: Colors.grey,
                                                        size: 48,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        
                                        // Info display
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Size: $wasteSize",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Location: ${location.length > 25 ? '${location.substring(0, 25)}...' : location}",
                                                    style: const TextStyle(fontSize: 14),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                timestamp != null ? _formatTimestamp(timestamp) : 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Action buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _showDetailsDialog(context, issueData, reportId),
                                                icon: const Icon(Icons.visibility, size: 18),
                                                label: const Text('View Details'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.blue,
                                                  side: const BorderSide(color: Colors.blue),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: hasUpvoted ? null : () {
                                                  _upvoteIssue(context, reportId);
                                                },
                                                icon: Icon(
                                                  hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                                                  size: 18,
                                                ),
                                                label: Text(hasUpvoted ? 'Upvoted' : 'Upvote'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: hasUpvoted ? Colors.grey.shade400 : Colors.green,
                                                  foregroundColor: Colors.white,
                                                  disabledBackgroundColor: Colors.grey.shade300,
                                                  disabledForegroundColor: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Priority badge for high priority issues
                              if (isHighPriority)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.priority_high, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'High Priority',
                                          style: TextStyle(
                                            color: Colors.white, 
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  // New: Method to show filter dialog
  Future<void> _showFilterDialog(BuildContext context) async {
    String? tempStatus = _filterByStatus;
    String? tempWasteType = _filterByWasteType;
    String? tempWasteSize = _selectedWasteSize;
    DateTime? tempDate = _selectedDate;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Filter Reports'),
          content: StatefulBuilder( // Use StatefulBuilder for dialog content
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Status Filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      value: tempStatus,
                      items: [null, ..._statusTypes].map((String? value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value ?? 'All Statuses'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          tempStatus = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    // Waste Type Filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Waste Type'),
                      value: tempWasteType,
                      items: [null, ..._wasteTypes].map((String? value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value ?? 'All Types'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          tempWasteType = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    // Waste Size Filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Waste Size'),
                      value: tempWasteSize,
                      items: [null, ..._wasteSizes].map((String? value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value ?? 'All Sizes'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          tempWasteSize = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    // Date Filter
                    ListTile(
                      title: Text(tempDate == null 
                          ? 'Select Date' 
                          : 'Date: ${_formatTimestamp(Timestamp.fromDate(tempDate!))}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempDate ?? DateTime.now(),
                          firstDate: DateTime(2020), // Adjust as needed
                          lastDate: DateTime.now().add(const Duration(days: 365)), // Adjust as needed
                        );
                        if (picked != null && picked != tempDate) {
                          setDialogState(() {
                            tempDate = picked;
                          });
                        }
                      },
                    ),
                    if (tempDate != null)
                      TextButton(
                        child: const Text('Clear Date Filter'),
                        onPressed: () {
                          setDialogState(() {
                            tempDate = null;
                          });
                        },
                      )
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Clear All'),
              onPressed: () {
                setState(() {
                  _filterByStatus = null;
                  _filterByWasteType = null;
                  _selectedWasteSize = null;
                  _selectedDate = null;
                });
                _resetAndFetchIssues();
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Apply'),
              onPressed: () {
                bool filtersChanged = _filterByStatus != tempStatus ||
                                    _filterByWasteType != tempWasteType ||
                                    _selectedWasteSize != tempWasteSize ||
                                    _selectedDate != tempDate;
                if (filtersChanged) {
                  setState(() {
                    _filterByStatus = tempStatus;
                    _filterByWasteType = tempWasteType;
                    _selectedWasteSize = tempWasteSize;
                    _selectedDate = tempDate;
                  });
                  _resetAndFetchIssues();
                }
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // New: Method to show sort dialog
  Future<void> _showSortDialog(BuildContext context) async {
    String tempSortBy = _sortBy;
    bool tempSortDescending = _sortDescending;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sort Reports'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Sort By'),
                    value: tempSortBy,
                    items: const [
                      DropdownMenuItem(value: 'timestamp', child: Text('Date Reported')),
                      DropdownMenuItem(value: 'upvoteCount', child: Text('Upvotes')),
                      DropdownMenuItem(value: 'wasteType', child: Text('Waste Type')),
                      DropdownMenuItem(value: 'status', child: Text('Status')),
                      DropdownMenuItem(value: 'wasteSize', child: Text('Waste Size')),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          tempSortBy = newValue;
                        });
                      }
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Descending Order'),
                    value: tempSortDescending,
                    onChanged: (bool value) {
                      setDialogState(() {
                        tempSortDescending = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Apply'),
              onPressed: () {
                if (_sortBy != tempSortBy || _sortDescending != tempSortDescending) {
                  setState(() {
                    _sortBy = tempSortBy;
                    _sortDescending = tempSortDescending;
                  });
                  _resetAndFetchIssues();
                }
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}