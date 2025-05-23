import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  String _workerName = 'Worker';
  List<Map<String, dynamic>> _assignedTasks = [];
  List<Map<String, dynamic>> _inProgressTasks = [];
  List<Map<String, dynamic>> _completedTasks = [];
  int _todayTasksCount = 0;
  int _totalTasksCount = 0;  @override
  void initState() {
    super.initState();
    _loadWorkerData();
    _fetchTasks();
    
    // Set up a listener for new task assignments
    _setupTaskListener();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  // Setup real-time listener for new task assignments
  void _setupTaskListener() {
    User? user = _auth.currentUser;
    if (user == null) return;
    
    // Listen for tasks assigned to this worker with either assignedWorker or assignedWorkerId field
    _firestore
        .collection('waste_reports')
        .where('status', whereIn: ['assigned', 'Assigned'])
        .snapshots()
        .listen((snapshot) {
          // Only show notification if this is not the initial load
          if (!_isLoading && snapshot.docChanges.isNotEmpty) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                // Check if this task is assigned to current user
                final data = change.doc.data() as Map<String, dynamic>;
                if ((data['assignedWorker'] == user.uid) || 
                    (data['assignedWorkerId'] == user.uid)) {
                  // Show notification for new assignment
                  _showNewTaskNotification();
                  break;
                }
              }
            }
          }
          
          // Update the task list
          _fetchTasks();
        });
  }
  
  void _showNewTaskNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.notification_important, color: Colors.white),
            SizedBox(width: 8),
            Text('You have a new task assignment!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            // _tabController.animateTo(0); // Switch to assigned tasks tab
          },
        ),
      ),
    );
  }
  Future<void> _loadWorkerData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _workerName = data['name'] ?? data['username'] ?? 'Worker';
          });
        }
      }
    } catch (e) {
      print("Error loading worker data: $e");
    }
  }

  Future<void> _fetchTasks() async {
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

      List<Map<String, dynamic>> assignedTasks = [];
      List<Map<String, dynamic>> inProgressTasks = [];
      List<Map<String, dynamic>> completedTasks = [];
      
      // First query with assignedWorker field
      QuerySnapshot assignedSnapshot1 = await _firestore
          .collection('waste_reports')
          .where('assignedWorker', isEqualTo: user.uid)
          .where('status', whereIn: ['assigned', 'Assigned'])
          .get();
      
      // Second query with assignedWorkerId field
      QuerySnapshot assignedSnapshot2 = await _firestore
          .collection('waste_reports')
          .where('assignedWorkerId', isEqualTo: user.uid)
          .where('status', whereIn: ['assigned', 'Assigned'])
          .get();
      
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
      
      // Get today's completed count
      final DateTime today = DateTime.now();
      final DateTime startOfDay = DateTime(today.year, today.month, today.day);
      
      // Today's tasks with assignedWorker field
      QuerySnapshot todaySnapshot1 = await _firestore
          .collection('waste_reports')
          .where('assignedWorker', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
          
      // Today's tasks with assignedWorkerId field
      QuerySnapshot todaySnapshot2 = await _firestore
          .collection('waste_reports')
          .where('assignedWorkerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      // Total tasks with assignedWorker field
      QuerySnapshot totalSnapshot1 = await _firestore
          .collection('waste_reports')
          .where('assignedWorker', isEqualTo: user.uid)
          .get();
          
      // Total tasks with assignedWorkerId field
      QuerySnapshot totalSnapshot2 = await _firestore
          .collection('waste_reports')
          .where('assignedWorkerId', isEqualTo: user.uid)
          .get();

      // Process assigned tasks from both queries
      List<DocumentSnapshot> allAssignedDocs = [...assignedSnapshot1.docs, ...assignedSnapshot2.docs];
      Set<String> processedIds = {};
      
      for (var doc in allAssignedDocs) {
        // Skip duplicates if the same task appears in both queries
        if (processedIds.contains(doc.id)) continue;
        processedIds.add(doc.id);
        
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Convert timestamp
        if (data['timestamp'] != null) {
          DateTime date = (data['timestamp'] as Timestamp).toDate();
          data['formattedDate'] = DateFormat('MMM dd, h:mm a').format(date);
          data['dateForSorting'] = date;
        } else {
          data['formattedDate'] = 'Unknown date';
        }
        
        assignedTasks.add(data);
      }

      // Sort assigned tasks by date (newest first)
      assignedTasks.sort((a, b) {
        if (a.containsKey('dateForSorting') && b.containsKey('dateForSorting')) {
          return (b['dateForSorting'] as DateTime).compareTo(a['dateForSorting'] as DateTime);
        }
        return 0;
      });

      // Process in-progress tasks from both queries
      List<DocumentSnapshot> allInProgressDocs = [...inProgressSnapshot1.docs, ...inProgressSnapshot2.docs];
      processedIds = {};
      
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

      // Process completed tasks from both queries
      List<DocumentSnapshot> allCompletedDocs = [...completedSnapshot1.docs, ...completedSnapshot2.docs];
      processedIds = {};
      
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
      });      // Remove duplicates from counts
      Set<String> todayIds = {};
      for (var doc in [...todaySnapshot1.docs, ...todaySnapshot2.docs]) {
        todayIds.add(doc.id);
      }
      
      Set<String> totalIds = {};
      for (var doc in [...totalSnapshot1.docs, ...totalSnapshot2.docs]) {
        totalIds.add(doc.id);
      }

      setState(() {
        _assignedTasks = assignedTasks;
        _inProgressTasks = inProgressTasks;
        _completedTasks = completedTasks;
        _todayTasksCount = todayIds.length;
        _totalTasksCount = totalIds.length;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching tasks: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startTask(Map<String, dynamic> task) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update task status
      await _firestore.collection('waste_reports').doc(task['id']).update({
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
      });

      // Refresh tasks
      _fetchTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task started successfully')),
      );
    } catch (e) {
      print("Error starting task: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting task: $e')),
      );
    }
  }

  Future<void> _completeTask(Map<String, dynamic> task) async {
    // Take a photo of completed task
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please take a photo to complete the task')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Convert image to base64
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
      _fetchTasks();

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
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Worker Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/profilew'),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchTasks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(),
                    const SizedBox(height: 8),
                    _buildStatCards(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
  
// Build greeting widget with attractive gradient styling
Widget _buildGreeting() {
  final hour = DateTime.now().hour;
  String greeting;
  IconData icon;
  Color iconColor;
  
  if (hour < 12) {
    greeting = 'Good Morning,';
    icon = Icons.wb_sunny_outlined;
    iconColor = Colors.orange;
  } else if (hour < 17) {
    greeting = 'Good Afternoon,';
    icon = Icons.wb_sunny;
    iconColor = Colors.amber;
  } else {
    greeting = 'Good Evening,';
    icon = Icons.nightlight_round;
    iconColor = Colors.indigo;
  }
  
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.green.shade700,
          Colors.green.shade600,
          Colors.green.shade800,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.green.shade700.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _workerName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready to make the city cleaner!',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today',
            _todayTasksCount.toString(),
            Icons.today,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Tasks',
            _totalTasksCount.toString(),
            Icons.task_alt,
            Colors.blue,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final size = MediaQuery.of(context).size;
    
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.width * 0.04),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size.width * 0.04),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.1),
            ],
          ),
        ),
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.03),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: size.width * 0.06),
            ),
            SizedBox(height: size.height * 0.02),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: size.width * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(height: size.height * 0.01),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: size.width * 0.035,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyTasksCard({required String section}) {
    String message;
    IconData icon;
    
    if (section.contains('In Progress')) {
      message = 'No tasks in progress at the moment';
      icon = Icons.pending_actions;
    } else if (section.contains('Completed')) {
      message = 'No tasks completed yet';
      icon = Icons.check_circle_outline;
    } else {
      message = 'No new tasks assigned to you at the moment';
      icon = Icons.assignment;
    }
    
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
              Icon(icon, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                message,
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
  
  Widget _buildAssignedTaskCard(Map<String, dynamic> task) {
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
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              task['formattedDate'] ?? 'Unknown date',
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
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ASSIGNED',
                            style: TextStyle(
                              color: Colors.orange[800],
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
                    onPressed: () => _startTask(task),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Task'),
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

  Widget _buildInProgressTaskCard(Map<String, dynamic> task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                            Icon(Icons.play_circle, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Started: ${task['formattedStartDate'] ?? 'Unknown'}',
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
                    label: const Text('Complete Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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

  Widget _buildCompletedTaskCard(Map<String, dynamic> task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                              'Completed: ${task['formattedCompletedDate'] ?? 'Unknown'}',
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTaskImage(String? imageBase64) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width * 0.2,
      height: size.width * 0.2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.width * 0.02),
        color: Colors.grey[200]!,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: imageBase64 != null && imageBase64.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(imageBase64),
                fit: BoxFit.cover,
              ),
            )
          : const Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.grey,
              ),
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green.shade700,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _workerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Waste Management Worker',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.home,
            title: 'Dashboard',
            onTap: () {
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.person,
            title: 'My Profile',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profilew');
            },
          ),
          _buildDrawerItem(
            icon: Icons.map,
            title: 'Task Map',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/worker_map');
            },
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'Completed Tasks',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/worker_history');
            },
          ),
          _buildDrawerItem(
            icon: Icons.note_add,
            title: 'Submit Daily Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/worker_daily_report');
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/worker_help');
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              Navigator.pop(context);
              await _auth.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/Loginpage',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
    // Build content based on the current bottom navigation index  // Build quick actions section with gradient styling
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTaskNavigationButton(
                  'Assigned Tasks',
                  _assignedTasks.length,
                  Icons.assignment,
                  Colors.orange,
                  () => Navigator.pushNamed(context, '/assigned_tasks'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTaskNavigationButton(
                  'In Progress',
                  _inProgressTasks.length,
                  Icons.pending_actions,
                  Colors.blue,
                  () => Navigator.pushNamed(context, '/in_progress_tasks'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTaskNavigationButton(
                  'Completed',
                  _completedTasks.length,
                  Icons.check_circle,
                  Colors.green,
                  () => Navigator.pushNamed(context, '/completed_tasks'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTaskNavigationButton(
                  'My Profile',
                  0,
                  Icons.person,
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/profilew'),
                  hideCount: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build task navigation button with gradient styling
  Widget _buildTaskNavigationButton(
    String title,
    int count,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool hideCount = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (!hideCount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build recent activity section with gradient styling
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade100,
                ],
              ),
              border: Border.all(
                color: Colors.green.shade200,
                width: 1,
              ),
            ),
            child: _buildRecentActivityList(),
          ),
        ],
      ),
    );
  }
  // Build recent activity list
  Widget _buildRecentActivityList() {
    // Combine recent tasks from all categories (last 5)
    List<Map<String, dynamic>> allTasks = [
      ..._completedTasks.take(2),
      ..._inProgressTasks.take(2),
      ..._assignedTasks.take(1),
    ];
    
    if (allTasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent activity',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your recent tasks will appear here',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: allTasks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = allTasks[index];
        return _buildActivityItem(task);
      },
    );
  }

  // Build individual activity item
  Widget _buildActivityItem(Map<String, dynamic> task) {
    IconData icon;
    Color statusColor;
    String statusText;
    String timeText;

    switch (task['status']) {
      case 'completed':
        icon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Completed';
        timeText = task['formattedCompletedDate'] ?? 'Unknown';
        break;
      case 'started':
        icon = Icons.pending_actions;
        statusColor = Colors.blue;
        statusText = 'In Progress';
        timeText = task['formattedStartDate'] ?? 'Unknown';
        break;
      default:
        icon = Icons.assignment;
        statusColor = Colors.orange;
        statusText = 'Assigned';
        timeText = task['formattedDate'] ?? 'Unknown';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: statusColor, size: 20),
      ),
      title: Text(
        'Task #${task['id'].toString().substring(0, 8)}',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task['location'] ?? 'Unknown location',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            timeText,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
      onTap: () => _viewTaskDetails(task),
    );
  }
}