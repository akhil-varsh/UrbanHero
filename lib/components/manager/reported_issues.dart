import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IssueReport {
  final String id;
  final String wasteSize;
  final String description;
  final String imageUrl;
  final String location;
  final DateTime timestamp;
  final int upvoteCount;
  final String status;
  final String wasteType;

  IssueReport({
    required this.id,
    required this.wasteSize,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.timestamp,
    this.upvoteCount = 0,
    required this.status,
    required this.wasteType,
  });

  factory IssueReport.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return IssueReport(
      id: doc.id,
      wasteSize: data['wasteSize'] ?? 'Unknown',
      description: data['description'] ?? '',
      imageUrl: data['imageBase64'] ?? '', // Base64 or URL
      location: data['location'] ?? 'Unknown',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      upvoteCount: data['upvoteCount'] ?? 0,
      status: data['status'] ?? 'Pending',
      wasteType: data['wasteType'] ?? 'Unknown',
    );
  }
}

class ReportedIssues extends StatelessWidget {
  const ReportedIssues({super.key});

  Stream<List<IssueReport>> fetchReports() {
    final firestore = FirebaseFirestore.instance;

    return firestore
        .collection('waste_reports')
        .orderBy('upvoteCount', descending: true) // Prioritize by upvotes
        .orderBy('timestamp', descending: true) // Then by timestamp
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => IssueReport.fromFirestore(doc))
          .toList();
    });
  }
  void _showReportDetails(BuildContext context, IssueReport report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Report Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('Report ID', report.id),
                    _buildInfoRow('Waste Type', report.wasteType),
                    _buildInfoRow('Waste Size', report.wasteSize),
                    _buildInfoRow('Location', report.location),
                    _buildInfoRow('Date Reported',
                        report.timestamp.toString().split('.')[0]),
                    _buildInfoRow('Status', report.status, 
                      color: _getStatusColor(report.status)),
                    _buildInfoRow('Community Upvotes', report.upvoteCount.toString(), 
                      color: report.upvoteCount > 0 ? Colors.green : null),
                    const SizedBox(height: 15),
                    const Text(
                      'Description:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(report.description),
                    if (report.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      const Text(
                        'Attached Image:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImageWidget(report.imageUrl),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      // If the image is a URL
      return Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported),
        ),
      );
    } else {
      // If the image is Base64
      try {
        final decodedBytes = base64Decode(imageUrl);
        return Image.memory(
          decodedBytes,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Container(
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image),
        );
      }
    }
  }
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Assigned':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reported Issues'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<List<IssueReport>>(
        stream: fetchReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No reports found.'));
          } else {
            final reports = snapshot.data!;
            return ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    onTap: () => _showReportDetails(context, report),
                    contentPadding: const EdgeInsets.all(16),
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${report.upvoteCount}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: report.upvoteCount > 0 ? Colors.green.shade700 : Colors.grey,
                          ),
                        ),
                        Icon(
                          Icons.thumb_up,
                          color: report.upvoteCount > 0 ? Colors.green.shade700 : Colors.grey,
                          size: 16,
                        ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Waste: ${report.wasteType}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text('Size: ${report.wasteSize}'),
                        Text(
                          report.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Reported on: ${report.timestamp.toString().split(' ')[0]}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
