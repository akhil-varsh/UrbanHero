import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../../models/worker_profile.dart';

class WorkerManagement extends StatefulWidget {
  const WorkerManagement({super.key});

  @override
  _WorkerManagementState createState() => _WorkerManagementState();
}

class _WorkerManagementState extends State<WorkerManagement> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> issues = [];
  Map<String, dynamic>? selectedWorker;

  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Available', 'Busy', 'Inactive'];
  List<Map<String, dynamic>> _filteredWorkers = [];
  List<String> _selectedSpecializations = [];
  List<String> _availableSpecializations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchWorkers();
    fetchIssues();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch workers from worker_profiles collection in Firestore
  Future<void> fetchWorkers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch worker profiles that are complete
      final profileSnapshot = await _firestore
          .collection('worker_profiles')
          .where('isProfileComplete', isEqualTo: true)
          .get();
          
      print('Found ${profileSnapshot.docs.length} worker profiles in the database');
      
      List<Map<String, dynamic>> workersList = [];
      Set<String> specializations = {};
      
      // Process worker profiles
      for (var doc in profileSnapshot.docs) {
        try {
          var data = doc.data();
          
          // Add specialization to the set for filtering
          if (data['specialization'] != null && data['specialization'].toString().isNotEmpty) {
            specializations.add(data['specialization']);
          }
          
          Map<String, dynamic> workerData = {
            'id': doc.id,
            'userId': data['userId'] ?? '',
            'username': data['username'] ?? 'Unnamed Worker',
            'email': data['email'] ?? 'No email',
            'phone': data['phone'] ?? 'No phone',
            'location': data['location'] ?? 'No location set',
            'profileImageBase64': data['profileImageBase64'],
            'availability': data['availability'] ?? 'Available',
            'specialization': data['specialization'] ?? 'General',
            'skills': data['skills'] ?? [],
            'experienceYears': data['experienceYears'] ?? 0,
            'rating': data['rating'] ?? 0.0,
            'tasksAssigned': 0,
            'tasksInProgress': 0,
            'tasksCompleted': 0,
            'lastActive': data['lastUpdated'],
            'isAvailable': data['availability'] == 'Available',
          };
          workersList.add(workerData);
        } catch (e) {
          print('Error processing worker document ${doc.id}: $e');
        }
      }
      
      // If no workers were found, show empty state
      if (workersList.isEmpty) {
        setState(() {
          workers = [];
          _filteredWorkers = [];
          _isLoading = false;
        });
        return;
      }
      
      // Continue with the rest of the worker processing
      // Run a batch query for all active tasks to minimize database reads
      final tasksSnapshot = await _firestore
          .collection('waste_reports')
          .where('status', whereIn: ['assigned', 'started', 'completed'])
          .get();
          
      // Create maps for faster lookups
      Map<String, int> assignedTasksCount = {};
      Map<String, int> inProgressTasksCount = {};
      Map<String, int> completedTasksCount = {};
      Map<String, Timestamp> lastActivityMap = {};
      
      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        final workerId = data['assignedWorkerId'];
        
        if (workerId != null) {
          final status = data['status'];
          
          // Update counts based on status
          if (status == 'assigned') {
            assignedTasksCount[workerId] = (assignedTasksCount[workerId] ?? 0) + 1;
          } else if (status == 'started') {
            inProgressTasksCount[workerId] = (inProgressTasksCount[workerId] ?? 0) + 1;
          } else if (status == 'completed') {
            completedTasksCount[workerId] = (completedTasksCount[workerId] ?? 0) + 1;
          }
          
          // Track last activity
          final timestamp = data['timestamp'] as Timestamp;
          if (lastActivityMap[workerId] == null || 
              lastActivityMap[workerId]!.compareTo(timestamp) < 0) {
            lastActivityMap[workerId] = timestamp;
          }
        }
      }
      
      // Now update the stats for each worker in a single pass
      for (int i = 0; i < workersList.length; i++) {
        final userId = workersList[i]['userId'];
        
        workersList[i]['tasksAssigned'] = assignedTasksCount[userId] ?? 0;
        workersList[i]['tasksInProgress'] = inProgressTasksCount[userId] ?? 0;
        workersList[i]['tasksCompleted'] = completedTasksCount[userId] ?? 0;
        
        // Use last task activity if more recent than profile update
        if (lastActivityMap[userId] != null) {
          if (workersList[i]['lastActive'] == null || 
              lastActivityMap[userId]!.compareTo(workersList[i]['lastActive']) > 0) {
            workersList[i]['lastActive'] = lastActivityMap[userId];
          }
        }
        
        // Determine availability based on task counts and stated availability
        final totalActiveTasks = (assignedTasksCount[userId] ?? 0) + 
                              (inProgressTasksCount[userId] ?? 0);
        final String availability = workersList[i]['availability'];
        workersList[i]['isAvailable'] = availability == 'Available' && totalActiveTasks < 3;
      }
      
      // Sort workers - prioritize available workers first, then by workload
      workersList.sort((a, b) {
        // First sort by availability
        if (a['isAvailable'] && !b['isAvailable']) return -1;
        if (!a['isAvailable'] && b['isAvailable']) return 1;
        
        // Then sort by current workload (busy workers last)
        int busyA = (a['tasksAssigned'] as int) + (a['tasksInProgress'] as int);
        int busyB = (b['tasksAssigned'] as int) + (b['tasksInProgress'] as int); 
        return busyA.compareTo(busyB); // Ascending order - less busy first
      });

      // Store available specializations for filtering
      _availableSpecializations = specializations.toList()..sort();
      
      if (mounted) {
        setState(() {
          workers = workersList;
          _applyFiltersAndSearch(); // Apply any active filters or search
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching workers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          workers = [];
          _filteredWorkers = [];
        });
      }
    }
  }
  
  // Apply filters and search to the workers list
  void _applyFiltersAndSearch() {
    List<Map<String, dynamic>> result = List.from(workers);
    
    // Apply filter
    if (_selectedFilter != 'All') {
      switch (_selectedFilter) {
        case 'Available':
          result = result.where((worker) => worker['isAvailable']).toList();
          break;
        case 'Busy':
          result = result.where((worker) => 
            !worker['isAvailable'] && 
            ((worker['tasksAssigned'] ?? 0) + (worker['tasksInProgress'] ?? 0)) > 0).toList();
          break;
        case 'Inactive':
          result = result.where((worker) => 
            worker['lastActive'] == null || 
            DateTime.now().difference((worker['lastActive'] as Timestamp).toDate()).inDays > 7).toList();
          break;
      }
    }

    // Apply specialization filter
    if (_selectedSpecializations.isNotEmpty) {
      result = result.where((worker) => 
        _selectedSpecializations.contains(worker['specialization'])).toList();
    }
    
    // Apply search
    if (_searchQuery.isNotEmpty) {
      result = result.where((worker) => 
        worker['username'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        worker['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        worker['specialization'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (worker['skills'] as List<dynamic>).any((skill) => skill.toString().toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }
    
    setState(() {
      _filteredWorkers = result;
    });
  }

  // Toggle specialization filter
  void _toggleSpecialization(String specialization) {
    setState(() {
      if (_selectedSpecializations.contains(specialization)) {
        _selectedSpecializations.remove(specialization);
      } else {
        _selectedSpecializations.add(specialization);
      }
      _applyFiltersAndSearch();
    });
  }

  // Fetch issues from Firestore
  Future<void> fetchIssues() async {
    try {
      final snapshot = await _firestore
          .collection('waste_reports')
          .orderBy('timestamp', descending: true)
          .get(); // Fetch all reports

      List<Map<String, dynamic>> issuesList = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        issuesList.add(data);
      }
      
      // Sort issues to prioritize pending reports first
      issuesList.sort((a, b) {
        // If a is pending and b is not, a comes first
        if (a['status'] == 'Pending' && b['status'] != 'Pending') return -1;
        // If b is pending and a is not, b comes first
        if (b['status'] == 'Pending' && a['status'] != 'Pending') return 1;
        // Otherwise sort by timestamp (newest first)
        Timestamp aTimestamp = a['timestamp'] as Timestamp;
        Timestamp bTimestamp = b['timestamp'] as Timestamp;
        return bTimestamp.compareTo(aTimestamp);
      });

      setState(() {
        issues = issuesList;
      });
    } catch (e) {
      print('Error fetching issues: $e');
    }
  }

  // Assign issue to worker - now requires explicit worker selection first
  Future<void> assignIssue(String issueId) async {
    // Check if a worker has been selected
    if (selectedWorker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a worker first')),
      );
      return;
    }

    try {
      await _firestore.collection('waste_reports').doc(issueId).update({
        'assignedWorkerId': selectedWorker!['userId'], // Store worker's UID
        'assignedWorkerName': selectedWorker!['username'], // Store worker's username
        'status': 'assigned', // Use lowercase to match worker's dashboard query
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task assigned to ${selectedWorker!['username']}')),
      );

      // Clear selected worker after assignment
      setState(() {
        selectedWorker = null;
      });
      
      // Refresh issues after assignment
      fetchIssues();
      fetchWorkers(); // Also refresh workers to update their task counts
    } catch (e) {
      print('Error assigning issue: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to assign task')),
      );
    }
  }

  void _selectWorker(Map<String, dynamic> worker) {
    setState(() {
      selectedWorker = worker;
    });
    
    // Switch to issues tab after selecting worker
    _tabController.animateTo(1);
  }

  // Add this method to fetch a specific worker by email
  Future<void> fetchWorkerByEmail(String email) async {
    setState(() {
      _isLoading = true;
      _searchQuery = email; // Update the search query to the email
    });
    
    try {
      final snapshot = await _firestore
          .collection('worker_profiles')
          .where('email', isEqualTo: email)
          .where('isProfileComplete', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No worker found with email: $email')),
        );
        setState(() {
          _isLoading = false;
          _applyFiltersAndSearch();
        });
        return;
      }

      // We've found workers, so process them
      await fetchWorkers(); // Refresh all workers
      
      // Set the search query to find this specific worker
      setState(() {
        _searchQuery = email;
        _applyFiltersAndSearch();
        
        // If there's exactly one worker found, select them automatically
        if (_filteredWorkers.length == 1) {
          selectedWorker = _filteredWorkers[0];
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Worker "${selectedWorker!['username']}" found and selected'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching worker by email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching worker: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch available workers with specified skills
  Future<void> fetchWorkersBySkills(List<String> requiredSkills) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Refresh all workers first
      await fetchWorkers();
      
      // Filter workers by skills
      setState(() {
        _filteredWorkers = workers.where((worker) {
          List<dynamic> workerSkills = worker['skills'] ?? [];
          return requiredSkills.every((skill) => workerSkills.contains(skill));
        }).toList();
        
        _isLoading = false;
        
        if (_filteredWorkers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No workers found with all required skills: ${requiredSkills.join(", ")}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${_filteredWorkers.length} workers with the required skills'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    } catch (e) {
      print('Error fetching workers by skills: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for workers: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Management'),
        backgroundColor: Colors.blue,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Workers', icon: Icon(Icons.people)),
            Tab(text: 'Issues', icon: Icon(Icons.report_problem)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Workers Tab
          _buildWorkersTab(),
          
          // Issues Tab
          _buildIssuesTab(),
        ],
      ),
    );
  }
  
  Widget _buildWorkersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (workers.isEmpty) {
      // Show a friendly message when no workers are available
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Workers Available',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'There are no workers with completed profiles in the database yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Workers need to sign up and complete their profiles before they appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: fetchWorkers,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Workers List'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Regular workers view when workers are available
    return Column(
      children: [
        // Header with title and refresh button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Worker Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: fetchWorkers,
                tooltip: 'Refresh worker list',
              ),
            ],
          ),
        ),
        
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search workers by name, email, skills, or specialization',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFiltersAndSearch();
              });
            },
          ),
        ),

        // Filter options
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final bool isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                        _applyFiltersAndSearch();
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue.shade800 : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Specialization filters (if available)
        if (_availableSpecializations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Specialization: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ..._availableSpecializations.map((spec) {
                    final bool isSelected = _selectedSpecializations.contains(spec);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(spec),
                        selected: isSelected,
                        onSelected: (_) => _toggleSpecialization(spec),
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        
        // Selected worker indicator
        if (selectedWorker != null)
          Container(
            color: Colors.green.shade50,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected: ${selectedWorker!['username']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedWorker = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          
        // Workers count and availability summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _filteredWorkers.isEmpty && _searchQuery.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'No workers found matching "$_searchQuery"',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            : Row(
                children: [
                  Text(
                    'Showing ${_filteredWorkers.length} of ${workers.length} workers',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const Spacer(),
                  const Text(
                    'Available: ',
                    style: TextStyle(fontSize: 14),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Busy: ',
                    style: TextStyle(fontSize: 14),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
        ),
        
        // Workers list
        Expanded(
          child: _filteredWorkers.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty 
                            ? 'No workers found matching your search'
                            : 'No workers found matching the selected filter',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedFilter = 'All';
                            _selectedSpecializations = [];
                            _applyFiltersAndSearch();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Filters'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredWorkers.length,
                  itemBuilder: (context, index) {
                    final worker = _filteredWorkers[index];
                    final bool isSelected = selectedWorker != null && 
                        selectedWorker!['id'] == worker['id'];
                    final bool isAvailable = worker['isAvailable'] ?? true;
                    
                    // Calculate worker stats
                    final int totalAssigned = (worker['tasksAssigned'] ?? 0) + (worker['tasksInProgress'] ?? 0);
                    final int completed = worker['tasksCompleted'] ?? 0;
                    final String completionRate = totalAssigned > 0 
                        ? '${((completed / (completed + totalAssigned)) * 100).toStringAsFixed(0)}%'
                        : '0%';
                        
                    // Format last active time
                    String lastActiveText = 'No activity yet';
                    if (worker['lastActive'] != null) {
                      final DateTime lastActive = (worker['lastActive'] as Timestamp).toDate();
                      final DateTime now = DateTime.now();
                      final Duration difference = now.difference(lastActive);
                      
                      if (difference.inDays > 0) {
                        lastActiveText = '${difference.inDays} days ago';
                      } else if (difference.inHours > 0) {
                        lastActiveText = '${difference.inHours} hours ago';
                      } else if (difference.inMinutes > 0) {
                        lastActiveText = '${difference.inMinutes} minutes ago';
                      } else {
                        lastActiveText = 'Just now';
                      }
                    }

                    // Worker's skills
                    final List<dynamic> skills = worker['skills'] ?? [];
                    final String skillsText = skills.isEmpty 
                        ? 'No skills specified' 
                        : skills.join(', ');
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? Colors.green : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Worker avatar or profile image with availability indicator
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isSelected ? Colors.green : Colors.blue,
                                      radius: 24,
                                      child: worker['profileImageBase64'] != null && worker['profileImageBase64'].isNotEmpty 
                                        ? ClipOval(
                                            child: Image.memory(
                                              base64Decode(worker['profileImageBase64']),
                                              fit: BoxFit.cover,
                                              width: 48,
                                              height: 48,
                                            ),
                                          )
                                        : Text(
                                            worker['username'].toString().isNotEmpty 
                                              ? worker['username'].substring(0, 1).toUpperCase()
                                              : 'W',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: isAvailable ? Colors.green : Colors.orange,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Worker main info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            worker['username'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Display specialization if available
                                          if (worker['specialization'] != null && worker['specialization'] != 'General')
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                worker['specialization'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            worker['email'],
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Last active: $lastActiveText',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Experience & availability
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.work, size: 14),
                                        const SizedBox(width: 4),
                                        Text('${worker['experienceYears']} years exp.'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAvailable ? Colors.green.shade100 : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      worker['availability'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: isAvailable ? Colors.green.shade800 : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Skills section
                            if (skills.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Skills:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: (skills).map((skill) => Chip(
                                        label: Text(
                                          skill.toString(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.grey.shade100,
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      )).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // Task statistics
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildWorkerStatCard(
                                  'Assigned', 
                                  worker['tasksAssigned'].toString(), 
                                  Colors.orange,
                                ),
                                _buildWorkerStatCard(
                                  'In Progress', 
                                  worker['tasksInProgress'].toString(), 
                                  Colors.blue,
                                ),
                                _buildWorkerStatCard(
                                  'Completed', 
                                  worker['tasksCompleted'].toString(), 
                                  Colors.green,
                                ),
                                _buildWorkerStatCard(
                                  'Completion Rate', 
                                  completionRate,
                                  Colors.purple,
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // View worker details
                                    // TODO: Implement worker detail screen
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('View Details'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _selectWorker(worker),
                                  icon: isSelected 
                                    ? const Icon(Icons.check) 
                                    : const Icon(Icons.add_task),
                                  label: Text(isSelected ? 'Selected' : 'Select for Task'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected ? Colors.green : Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWorkerStatCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.1),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildIssuesTab() {
    // Count pending reports that need attention
    int pendingCount = issues.where((issue) => 
      issue['status'] == 'Pending' && issue['assignedWorkerId'] == null).length;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Worker selection status
          if (selectedWorker != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ready to assign tasks to:',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                        Text(
                          selectedWorker!['username'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _tabController.animateTo(0);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Change'),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Please select a worker first before assigning tasks',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _tabController.animateTo(0);
                    },
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Select'),
                  ),
                ],
              ),
            ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Issues Reported',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.priority_high, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '$pendingCount Pending',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchIssues,
            tooltip: 'Refresh issue list',
          ),
          Expanded(
            child: issues.isEmpty
                ? const Center(child: Text("No issues available"))
                : ListView(
              children: [
                // Pending Issues - new section specifically for pending issues
                if (issues.any((issue) => issue['status'] == 'Pending' && issue['assignedWorkerId'] == null))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.priority_high, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Pending Issues - Need Assignment',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ...issues.where((issue) => 
                  issue['status'] == 'Pending' && issue['assignedWorkerId'] == null).map((issue) {
                  return issueCard(issue, isAssigned: false, isPending: true);
                }),

                // Other Unassigned Issues
                if (issues.any((issue) => 
                  issue['assignedWorkerId'] == null && issue['status'] != 'Pending'))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Other Unassigned Issues',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ...issues.where((issue) => 
                  issue['assignedWorkerId'] == null && issue['status'] != 'Pending').map((issue) {
                  return issueCard(issue, isAssigned: false, isPending: false);
                }),

                // Assigned Issues
                if (issues.any((issue) => issue['assignedWorkerId'] != null))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Assigned Issues',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ...issues.where((issue) => issue['assignedWorkerId'] != null).map((issue) {
                  return issueCard(issue, isAssigned: true, isPending: false);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Function to build issue cards
  Widget issueCard(Map<String, dynamic> issue, {required bool isAssigned, required bool isPending}) {
    final bool canAssign = !isAssigned && selectedWorker != null;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isPending ? Colors.red.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isPending 
          ? BorderSide(color: Colors.red.shade200, width: 1.5)
          : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.priority_high, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'PENDING',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isPending) const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAssigned ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Waste Size: ${issue['wasteSize'] ?? 'Unknown'}',
                    style: TextStyle(
                      color: isAssigned ? Colors.green.shade800 : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (issue['timestamp'] != null)
                  Expanded(
                    child: Text(
                      _formatTimestamp(issue['timestamp']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
            if (isPending) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'This issue requires worker assignment',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Description: ${issue['description'] ?? 'No description'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Location: ${issue['formattedAddress'] ?? issue['location'] ?? 'No location'}'),
            if (issue['wasteType'] != null) ...[
              const SizedBox(height: 4),
              Text('Waste Type: ${issue['wasteType']}'),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Reported by: ${issue['username'] ?? 'Unknown user'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAssigned 
                  ? Colors.green.withOpacity(0.1) 
                  : isPending
                    ? Colors.red.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    isAssigned 
                      ? Icons.check_circle 
                      : isPending
                        ? Icons.priority_high
                        : Icons.person_off, 
                    size: 16, 
                    color: isAssigned 
                      ? Colors.green 
                      : isPending
                        ? Colors.red
                        : Colors.orange
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAssigned
                        ? 'Assigned to: ${issue['assignedWorkerName']}'
                        : isPending
                          ? 'PENDING ASSIGNMENT'
                          : 'Not Assigned',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAssigned 
                        ? Colors.green 
                        : isPending
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!isAssigned)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canAssign 
                          ? () => assignIssue(issue['id']) 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPending ? Colors.red : Colors.green,
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      child: Text(
                        canAssign 
                            ? 'Assign to ${selectedWorker!['username']}' 
                            : 'Select worker first',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Helper function to format timestamp
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
