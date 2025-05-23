import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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

class CompletedTasksPage extends StatefulWidget {
  const CompletedTasksPage({super.key});

  @override
  State<CompletedTasksPage> createState() => _CompletedTasksPageState();
}

class _CompletedTasksPageState extends State<CompletedTasksPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _completedTasks = [];

  @override
  void initState() {
    super.initState();
    _fetchCompletedTasks();
  }

  Future<void> _fetchCompletedTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> completedTasks = [];

      // Completed tasks with assignedWorker field
      QuerySnapshot completedSnapshot1 = await _firestore
          .collection('waste_reports')
          .where('assignedWorker', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      // Completed tasks with assignedWorkerId field
      QuerySnapshot completedSnapshot2 = await _firestore
          .collection('waste_reports')
          .where('assignedWorkerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      // Process completed tasks from both queries
      List<DocumentSnapshot> allCompletedDocs = [...completedSnapshot1.docs, ...completedSnapshot2.docs];
      Set<String> processedIds = {};

      for (var doc in allCompletedDocs) {
        // Skip duplicates
        if (processedIds.contains(doc.id)) continue;
        processedIds.add(doc.id);

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convert timestamp for completion time
        if (data['completedAt'] != null) {
          DateTime completedDate = (data['completedAt'] as Timestamp).toDate();
          data['formattedCompletedDate'] = DateFormat('MMM dd, h:mm a').format(completedDate);
          data['dateForSorting'] = completedDate;
        } else {
          data['formattedCompletedDate'] = 'Unknown date';
        }

        completedTasks.add(data);
      }

      // Sort completed tasks by completion date (newest first)
      completedTasks.sort((a, b) {
        if (a.containsKey('dateForSorting') && b.containsKey('dateForSorting')) {
          return (b['dateForSorting'] as DateTime).compareTo(a['dateForSorting'] as DateTime);
        }
        return 0;
      });

      setState(() {
        _completedTasks = completedTasks;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching completed tasks: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  void _viewTaskDetails(Map<String, dynamic> task) {
    // Create a WasteReport object from the map
    DateTime timestamp = DateTime.now();
    if (task['timestamp'] != null) {
      timestamp = (task['timestamp'] as Timestamp).toDate();
    }
    
    final report = WasteReport(
      id: task['id'] ?? '',
      description: task['description'] ?? 'No description',
      imageBase64: task['imageBase64'] ?? '',
      location: task['location'] ?? 'Unknown location',
      timestamp: timestamp,
      wasteSize: task['wasteSize'] ?? 'Unknown size',
      status: task['status'] ?? 'unknown',
    );
    
    Navigator.pushNamed(
      context,
      '/task_details',
      arguments: report,
    );
  }

  Widget _buildTaskImage(String? imageBase64) {
    if (imageBase64 == null || imageBase64.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image, color: Colors.grey[400], size: 30),
      );
    }

    try {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: MemoryImage(base64Decode(imageBase64)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.broken_image, color: Colors.grey[400], size: 30),
      );
    }
  }

  Widget _buildCompletedImage(String? completedImageBase64) {
    if (completedImageBase64 == null || completedImageBase64.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.image, color: Colors.grey[400], size: 20),
      );
    }

    try {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          image: DecorationImage(
            image: MemoryImage(base64Decode(completedImageBase64)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.broken_image, color: Colors.grey[400], size: 20),
      );
    }
  }

  Widget _buildCompletedTaskCard(Map<String, dynamic> task) {
    final size = MediaQuery.of(context).size;
    return Card(
      margin: EdgeInsets.only(bottom: size.height * 0.02),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.width * 0.04),
      ),
      child: InkWell(
        onTap: () => _viewTaskDetails(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTaskImage(task['imageBase64']),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task #${task['id'].toString().substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task['location'] ?? 'Unknown location',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Completed: ${task['formattedCompletedDate'] ?? 'Unknown date'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        'After',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildCompletedImage(task['completedImageBase64']),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _viewTaskDetails(task),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Task Completed',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTasksCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No tasks completed yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pull down to refresh',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text(
          'Completed Tasks',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCompletedTasks,
              child: _completedTasks.isEmpty
                  ? Center(child: _buildEmptyTasksCard())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _completedTasks.length,
                      itemBuilder: (context, index) => _buildCompletedTaskCard(_completedTasks[index]),
                    ),
            ),
    );
  }
}
