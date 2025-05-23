import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkerReports extends StatefulWidget {
  const WorkerReports({super.key});

  @override
  _WorkerReportsState createState() => _WorkerReportsState();
}

class _WorkerReportsState extends State<WorkerReports> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Filter variables
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String? _selectedWorker;
  String? _selectedArea;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Lists for filters
  List<String> _workers = [];
  final List<String> _areas = ['North', 'East', 'West', 'South']; // Predefined areas
  
  // Image viewer state
  bool _showImageViewer = false;
  List<String> _currentImages = [];
  int _currentImageIndex = 0;
    @override
  void initState() {
    super.initState();
    _fetchFilterOptions();
    
    // Set initial date filters to last 7 days
    _selectedEndDate = DateTime.now();
    _selectedStartDate = _selectedEndDate!.subtract(const Duration(days: 7));
    
    // Initialize search controller
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
    Future<void> _fetchFilterOptions() async {
    try {
      // Fetch unique worker names
      final workersSnapshot = await _firestore.collection('worker_reports')
          .orderBy('workerName')
          .get();
      
      Set<String> workerNames = {};
      
      for (var doc in workersSnapshot.docs) {
        final data = doc.data();
        if (data['workerName'] != null) {
          workerNames.add(data['workerName']);
        }
      }
      
      setState(() {
        _workers = workerNames.toList();
        // Areas are now predefined as North, East, West, South
      });
    } catch (e) {
      print('Error fetching filter options: $e');
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedStartDate) {
      setState(() {
        _selectedStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now(),
      firstDate: _selectedStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }
  void _resetFilters() {
    setState(() {
      _selectedWorker = null;
      _selectedArea = null;
      _selectedEndDate = DateTime.now();
      _selectedStartDate = _selectedEndDate!.subtract(const Duration(days: 7));
    });
  }
  
  // Helper method to get icon for each area
  IconData _getAreaIcon(String area) {
    switch (area) {
      case 'North':
        return Icons.arrow_upward;
      case 'South':
        return Icons.arrow_downward;
      case 'East':
        return Icons.arrow_forward;
      case 'West':
        return Icons.arrow_back;
      default:
        return Icons.location_on;
    }
  }
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = _firestore.collection('worker_reports')
        .orderBy('timestamp', descending: true);
    
    // Apply date filters
    if (_selectedStartDate != null) {
      // Convert to start of day
      DateTime startOfDay = DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day);
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
    }
    
    if (_selectedEndDate != null) {
      // Convert to end of day
      DateTime endOfDay = DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day, 23, 59, 59);
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }
    
    // Apply other filters
    if (_selectedWorker != null && _selectedWorker!.isNotEmpty) {
      query = query.where('workerName', isEqualTo: _selectedWorker);
    }
    
    if (_selectedArea != null && _selectedArea!.isNotEmpty) {
      query = query.where('area', isEqualTo: _selectedArea);
    }
    
    // Note: Search query filtering will be applied after fetching the data
    // since Firestore doesn't support direct text search
    
    return query;
  }

  void _viewImages(List<dynamic> images) {
    if (images.isEmpty) return;
    
    List<String> imageUrls = images.map((img) => img.toString()).toList();
    
    setState(() {
      _showImageViewer = true;
      _currentImages = imageUrls;
      _currentImageIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),      appBar: AppBar(
        title: const Text(
          'Worker Reports',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _buildReportsContent(),
          if (_showImageViewer) _buildImageViewer(),
        ],
      ),
    );
  }
  Widget _buildReportsContent() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No reports found'));
              }
              
              // Filter reports based on search query if provided
              var filteredDocs = snapshot.data!.docs;
              if (_searchQuery.isNotEmpty) {
                filteredDocs = filteredDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final searchText = _searchQuery.toLowerCase();
                  
                  // Search in worker name, area, summary, and notes
                  final workerName = (data['workerName'] as String? ?? '').toLowerCase();
                  final area = (data['area'] as String? ?? '').toLowerCase();
                  final summary = (data['summary'] as String? ?? '').toLowerCase();
                  final notes = (data['notes'] as String? ?? '').toLowerCase();
                  
                  return workerName.contains(searchText) || 
                      area.contains(searchText) || 
                      summary.contains(searchText) || 
                      notes.contains(searchText);
                }).toList();
              }
              
              if (filteredDocs.isEmpty) {
                return const Center(child: Text('No matching reports found'));
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return _buildReportCard(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
    Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search reports...',
                  prefixIcon: Icon(Icons.search, color: Colors.green.shade700),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  suffixIcon: _searchQuery.isNotEmpty ? 
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    ) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: () {
                _showFilterBottomSheet(context);
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          if (_selectedWorker != null)
            _buildFilterChip(
              label: 'Worker: $_selectedWorker',
              onDeleted: () {
                setState(() {
                  _selectedWorker = null;
                });
              },
              color: Colors.blue.shade100,
              iconColor: Colors.blue.shade700,
            ),
          if (_selectedArea != null)
            _buildFilterChip(
              label: 'Area: $_selectedArea',
              onDeleted: () {
                setState(() {
                  _selectedArea = null;
                });
              },
              color: Colors.green.shade100,
              iconColor: Colors.green.shade700,
            ),
          if (_selectedStartDate != null && _selectedEndDate != null)
            _buildFilterChip(
              label: 'Date: ${DateFormat('MM/dd').format(_selectedStartDate!)} - ${DateFormat('MM/dd').format(_selectedEndDate!)}',
              onDeleted: () {
                setState(() {
                  _selectedStartDate = DateTime.now().subtract(const Duration(days: 7));
                  _selectedEndDate = DateTime.now();
                });
              },
              color: Colors.orange.shade100,
              iconColor: Colors.orange.shade700,
            ),
          if (_selectedWorker != null || _selectedArea != null || _searchQuery.isNotEmpty)
            ActionChip(
              label: const Text('Reset All'),
              backgroundColor: Colors.grey.shade200,
              labelStyle: TextStyle(color: Colors.red.shade700),
              onPressed: () {
                setState(() {
                  _resetFilters();
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
    required Color color,
    required Color iconColor,
  }) {
    return Chip(
      label: Text(label),
      backgroundColor: color,
      labelStyle: TextStyle(color: iconColor, fontWeight: FontWeight.w500),
      deleteIconColor: iconColor,
      elevation: 0,
      side: BorderSide(color: color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      onDeleted: onDeleted,
    );
  }

  void _showDateFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(_selectedStartDate != null 
                  ? DateFormat('MM/dd/yyyy').format(_selectedStartDate!)
                  : 'Select'),
              onTap: () {
                Navigator.pop(context);
                _selectStartDate(context);
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(_selectedEndDate != null 
                  ? DateFormat('MM/dd/yyyy').format(_selectedEndDate!)
                  : 'Select'),
              onTap: () {
                Navigator.pop(context);
                _selectEndDate(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Filter Reports',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _selectedStartDate != null
                                      ? DateFormat('MM/dd/yyyy').format(_selectedStartDate!)
                                      : 'Start Date',
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _selectStartDate(context);
                                  _showFilterBottomSheet(context);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _selectedEndDate != null
                                      ? DateFormat('MM/dd/yyyy').format(_selectedEndDate!)
                                      : 'End Date',
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _selectEndDate(context);
                                  _showFilterBottomSheet(context);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Worker', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          value: _selectedWorker,
                          hint: const Text('Select Worker'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Workers'),
                            ),
                            ..._workers.map((worker) => DropdownMenuItem(
                              value: worker,
                              child: Text(worker),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedWorker = value == '' ? null : value;
                            });
                          },
                        ),                        const SizedBox(height: 20),
                        const Text('Area', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Area', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => setState(() => _selectedArea = null),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedArea == null ? Colors.green.shade100 : Colors.white,
                                        foregroundColor: _selectedArea == null ? Colors.green.shade700 : Colors.black87,
                                        elevation: _selectedArea == null ? 0 : 0,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: _selectedArea == null ? Colors.green.shade700 : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: const Text('All'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 2.5,
                                children: _areas.map((area) {
                                  return ElevatedButton.icon(
                                    onPressed: () => setState(() => _selectedArea = area),
                                    icon: Icon(
                                      _getAreaIcon(area),
                                      color: _selectedArea == area ? Colors.green.shade700 : Colors.grey.shade700,
                                    ),
                                    label: Text(area),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedArea == area ? Colors.green.shade100 : Colors.white,
                                      foregroundColor: _selectedArea == area ? Colors.green.shade700 : Colors.black87,
                                      elevation: _selectedArea == area ? 0 : 0,
                                      alignment: Alignment.centerLeft,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: _selectedArea == area ? Colors.green.shade700 : Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _resetFilters();
                                  });
                                },
                                child: const Text('Reset All'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  this.setState(() {}); // Refresh the main widget
                                },
                                child: const Text('Apply Filters'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> data) {
    // Process timestamp
    Timestamp timestamp = data['timestamp'] as Timestamp? ?? Timestamp.now();
    DateTime date = timestamp.toDate();
    String formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    
    // Process images
    List<dynamic> images = data['images'] as List<dynamic>? ?? [];
    int imageCount = images.length;
      // Process other fields
    String workerName = data['workerName'] as String? ?? 'Unknown';
    String area = data['area'] as String? ?? 'Unknown';
    
    // Fix for the type conversion issue - handle hoursWorked as double
    double hoursWorked = 0;
    if (data['hoursWorked'] != null) {
      hoursWorked = (data['hoursWorked'] is int) 
          ? (data['hoursWorked'] as int).toDouble()
          : data['hoursWorked'] as double;
    }
    
    String summary = data['summary'] as String? ?? 'No summary';
    String notes = data['notes'] as String? ?? '';
    String challenges = data['challenges'] as String? ?? 'None';
      return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      elevation: 3,
      shadowColor: Colors.green.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade100, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(
            'Report by $workerName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(_getAreaIcon(area), size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Area: $area',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: const Icon(Icons.person, color: Colors.green),
          ),
          children: [
            const Divider(),
            _buildInfoRow('Area', area),
            _buildInfoRow('Hours Worked', '${hoursWorked.toStringAsFixed(1)} hours'),
            _buildInfoRow('Summary', summary),
            if (notes.isNotEmpty && notes != 'na') _buildInfoRow('Notes', notes),
            _buildInfoRow('Challenges', challenges),
            
            if (imageCount > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Images',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  ActionChip(
                    avatar: const Icon(Icons.photo_library, size: 16),
                    label: Text('View $imageCount photos'),
                    onPressed: () => _viewImages(images),
                  ),
                ],
              ),
            ],

            if (imageCount > 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageCount > 3 ? 3 : imageCount,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => _viewImages(images),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[index],
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 100,
                                width: 100,
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 100,
                                width: 100,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (imageCount > 3) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _viewImages(images),
                  child: Text(
                    'View ${imageCount - 3} more...',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showImageViewer = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showImageViewer = false;
                    });
                  },
                ),
                Text(
                  '${_currentImageIndex + 1}/${_currentImages.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: () {
                    // Full screen view
                  },
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                itemCount: _currentImages.length,
                controller: PageController(initialPage: _currentImageIndex),
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.network(
                      _currentImages[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.white),
                              SizedBox(height: 10),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: _currentImageIndex > 0
                      ? () {
                          setState(() {
                            _currentImageIndex--;
                          });
                        }
                      : null,
                ),
                const SizedBox(width: 40),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onPressed: _currentImageIndex < _currentImages.length - 1
                      ? () {
                          setState(() {
                            _currentImageIndex++;
                          });
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
