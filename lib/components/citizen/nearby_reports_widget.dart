import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:UrbanHero/utils/geo_query_service.dart';
import 'package:UrbanHero/utils/upvote_service.dart';

class NearbyReportsWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final Function(bool didUpvote) onReportUpvoted;
  final String? excludeReportId;

  const NearbyReportsWidget({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.onReportUpvoted,
    this.excludeReportId,
  }) : super(key: key);

  @override
  _NearbyReportsWidgetState createState() => _NearbyReportsWidgetState();
}

class _NearbyReportsWidgetState extends State<NearbyReportsWidget> {
  final GeoQueryService _geoQueryService = GeoQueryService();
  final UpvoteService _upvoteService = UpvoteService();
  
  List<Map<String, dynamic>> _nearbyReports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNearbyReports();
  }

  @override
  void didUpdateWidget(NearbyReportsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude || 
        oldWidget.longitude != widget.longitude ||
        oldWidget.excludeReportId != widget.excludeReportId) {
      _fetchNearbyReports();
    }
  }

  Future<void> _fetchNearbyReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reports = await _geoQueryService.getNearbyReports(
        widget.latitude,
        widget.longitude,
        excludeReportId: widget.excludeReportId,
      );
      
      setState(() {
        _nearbyReports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load nearby reports: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _upvoteReport(String reportId) async {
    final success = await _upvoteService.upvoteReport(reportId);
    if (success) {
      widget.onReportUpvoted(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report upvoted successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      widget.onReportUpvoted(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already upvoted this report.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchNearbyReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_nearbyReports.isEmpty) {
      return const Center(
        child: Text('No nearby reports found.'),
      );
    }

    return ListView.builder(
      itemCount: _nearbyReports.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final report = _nearbyReports[index];
        final reportId = report['id'] as String;
        final wasteType = report['wasteType'] as String? ?? 'Unknown';
        final status = report['status'] as String? ?? 'Pending';
        final imageBase64 = report['imageBase64'] as String?;
        final description = report['description'] as String? ?? 'No description';
        final timestamp = report['timestamp'] as Timestamp?;
        final upvoteCount = report['upvoteCount'] as int? ?? 0;

        Color statusColor;
        switch (status) {
          case 'Resolved':
            statusColor = Colors.green;
            break;
          case 'In Progress':
            statusColor = Colors.orange;
            break;
          case 'Assigned':
            statusColor = Colors.blue;
            break;
          default:
            statusColor = Colors.red;
        }

        return Card(
          margin: const EdgeInsets.all(8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              if (imageBase64 != null && imageBase64.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  child: Image.memory(
                    base64Decode(imageBase64),
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waste type and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(
                            wasteType,
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.blue.shade700,
                        ),
                        Chip(
                          label: Text(
                            status,
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    
                    // Time ago and upvote button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (timestamp != null)
                          Text(
                            _getTimeAgo(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          )
                        else
                          const Text(
                            'Recently',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        
                        // Upvote section
                        Row(
                          children: [
                            Text(
                              '$upvoteCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            
                            // Upvote button
                            StreamBuilder<bool>(
                              stream: Stream.fromFuture(
                                _upvoteService.hasUserUpvoted(reportId),
                              ),
                              builder: (context, snapshot) {
                                final hasUpvoted = snapshot.data ?? false;
                                
                                return IconButton(
                                  icon: Icon(
                                    hasUpvoted 
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_outlined,
                                    color: hasUpvoted 
                                        ? Colors.green
                                        : Colors.grey.shade700,
                                  ),
                                  onPressed: () => _upvoteReport(reportId),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
