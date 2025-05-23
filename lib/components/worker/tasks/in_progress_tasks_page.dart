import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

class InProgressTasksPage extends StatefulWidget {
  const InProgressTasksPage({super.key});

  @override
  State<InProgressTasksPage> createState() => _InProgressTasksPageState();
}

class _InProgressTasksPageState extends State<InProgressTasksPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  List<Map<String, dynamic>> _inProgressTasks = [];

  @override
  void initState() {
    super.initState();
    _fetchInProgressTasks();
  }

  Future<void> _fetchInProgressTasks() async {
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

      List<Map<String, dynamic>> inProgressTasks = [];

      // In-progress tasks with assignedWorker field
      QuerySnapshot inProgressSnapshot1 = await _firestore
          .collection('waste_reports')
          .where('assignedWorker', isEqualTo: user.uid)
          .where('status', isEqualTo: 'started')
          .get();

      // In-progress tasks with assignedWorkerId field
      QuerySnapshot inProgressSnapshot2 = await _firestore
          .collection('waste_reports')
          .where('assignedWorkerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'started')
          .get();

      // Process in-progress tasks from both queries
      List<DocumentSnapshot> allInProgressDocs = [...inProgressSnapshot1.docs, ...inProgressSnapshot2.docs];
      Set<String> processedIds = {};

      for (var doc in allInProgressDocs) {
        // Skip duplicates
        if (processedIds.contains(doc.id)) continue;
        processedIds.add(doc.id);

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convert timestamp for start time
        if (data['startedAt'] != null) {
          DateTime startDate = (data['startedAt'] as Timestamp).toDate();
          data['formattedStartDate'] = DateFormat('MMM dd, h:mm a').format(startDate);
          data['dateForSorting'] = startDate;
        } else {
          data['formattedStartDate'] = 'Unknown date';
        }

        inProgressTasks.add(data);
      }

      // Sort in-progress tasks by start date (newest first)
      inProgressTasks.sort((a, b) {
        if (a.containsKey('dateForSorting') && b.containsKey('dateForSorting')) {
          return (b['dateForSorting'] as DateTime).compareTo(a['dateForSorting'] as DateTime);
        }
        return 0;
      });

      setState(() {
        _inProgressTasks = inProgressTasks;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching in-progress tasks: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeTask(Map<String, dynamic> task) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final File imgFile = File(image.path);
      final List<int> imageBytes = await imgFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Update task status
      await _firestore.collection('waste_reports').doc(task['id']).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedImageBase64': base64Image,
      });

      // Refresh tasks
      _fetchInProgressTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error completing task: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing task: $e')),
      );
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

  Widget _buildInProgressTaskCard(Map<String, dynamic> task) {
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
                            Icon(Icons.play_arrow, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Started: ${task['formattedStartDate'] ?? 'Unknown date'}',
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
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'IN PROGRESS',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  ElevatedButton.icon(
                    onPressed: () => _completeTask(task),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
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
              Icon(Icons.pending_actions, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No tasks in progress at the moment',
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
          'In Progress Tasks',
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
              onRefresh: _fetchInProgressTasks,
              child: _inProgressTasks.isEmpty
                  ? Center(child: _buildEmptyTasksCard())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _inProgressTasks.length,
                      itemBuilder: (context, index) => _buildInProgressTaskCard(_inProgressTasks[index]),
                    ),
            ),
    );
  }
}
