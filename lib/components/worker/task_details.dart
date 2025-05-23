import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({super.key});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  Map<String, dynamic>? _taskDetails;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskDetails(String taskId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot doc = await _firestore.collection('waste_reports').doc(taskId).get();
      
      if (doc.exists) {
        setState(() {
          _taskDetails = doc.data() as Map<String, dynamic>;
          _taskDetails!['id'] = doc.id;
          _notesController.text = _taskDetails!['workerNotes'] ?? '';
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error loading task details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading task details: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    if (_taskDetails == null) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.collection('waste_reports').doc(_taskDetails!['id']).update({
        'workerNotes': _notesController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notes saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _startTask() async {
    if (_taskDetails == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('waste_reports').doc(_taskDetails!['id']).update({
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
      });

      // Refresh task details
      await _loadTaskDetails(_taskDetails!['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task started successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting task: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeTask() async {
    if (_taskDetails == null) return;
    
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

      // Convert to base64
      final File imgFile = File(image.path);
      final List<int> imageBytes = await imgFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      await _firestore.collection('waste_reports').doc(_taskDetails!['id']).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedImageBase64': base64Image,
      });

      // Refresh task details
      await _loadTaskDetails(_taskDetails!['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing task: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _openMap() async {
    if (_taskDetails == null || _taskDetails!['location'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location information not available')),
      );
      return;
    }

    // Get location information
    String location = _taskDetails!['location'].toString();
    List<String> coordinates = location.split(',');
    if (coordinates.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid location format')),
      );
      return;
    }

    // Parse coordinates
    double? lat = double.tryParse(coordinates[0].trim());
    double? lng = double.tryParse(coordinates[1].trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid location coordinates')),
      );
      return;
    }

    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the map')),
      );
    }
  }

  String _getFormattedDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not available';
    return DateFormat('MMM dd, yyyy - h:mm a').format(timestamp.toDate());
  }

  Widget _buildActionButtons() {
    if (_taskDetails == null) return const SizedBox.shrink();
    
    final String status = _taskDetails!['status'] ?? '';
    
    if (status == 'assigned') {
      return ElevatedButton.icon(
        onPressed: _startTask,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Task'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
      );
    } else if (status == 'started') {
      return ElevatedButton.icon(
        onPressed: _completeTask,
        icon: const Icon(Icons.check),
        label: const Text('Mark Complete'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
      );
    } else {
      return const Text(
        'Task Completed',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Receive the task report from arguments
    final args = ModalRoute.of(context)!.settings.arguments;
    
    if (args != null && _taskDetails == null && !_isLoading) {
      final report = args as dynamic;
      _loadTaskDetails(report.id);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_taskDetails != null) {
                _loadTaskDetails(_taskDetails!['id']);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _taskDetails == null
              ? const Center(child: Text('No task details available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusBanner(),
                      const SizedBox(height: 16),
                      _buildTaskHeader(),
                      const SizedBox(height: 24),
                      _buildLocationSection(),
                      const SizedBox(height: 24),
                      _buildTimelineSection(),
                      const SizedBox(height: 24),
                      _buildReportedImage(),
                      if (_taskDetails!['status'] == 'completed') ...[
                        const SizedBox(height: 24),
                        _buildCompletedImage(),
                      ],
                      const SizedBox(height: 24),
                      _buildNotesSection(),
                      const SizedBox(height: 32),
                      Center(child: _buildActionButtons()),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusBanner() {
    final String status = _taskDetails!['status'] ?? '';
    Color color;
    IconData icon;
    String statusText;

    switch (status) {
      case 'assigned':
        color = Colors.orange;
        icon = Icons.assignment;
        statusText = 'ASSIGNED';
        break;
      case 'started':
        color = Colors.blue;
        icon = Icons.play_circle;
        statusText = 'IN PROGRESS';
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        statusText = 'COMPLETED';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        statusText = 'UNKNOWN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          if (status == 'started' || status == 'completed')
            Text(
              'Priority: High',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Task #${_taskDetails!['id'].toString().substring(0, 8)}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _taskDetails!['description'] ?? 'No description provided',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.blue[700],
              ),
              label: Text(
                _taskDetails!['wasteSize'] ?? 'Unknown size',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 13,
                ),
              ),
              backgroundColor: Colors.blue.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            if (_taskDetails!['reporterName'] != null)
              Chip(
                avatar: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: Colors.purple[700],
                ),
                label: Text(
                  'Reported by: ${_taskDetails!['reporterName']}',
                  style: TextStyle(
                    color: Colors.purple[700],
                    fontSize: 13,
                  ),
                ),
                backgroundColor: Colors.purple.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.directions, color: Colors.blue),
                  onPressed: _openMap,
                  tooltip: 'Get directions',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _taskDetails!['location'] ?? 'Address not available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            if (_taskDetails!['latitude'] != null && _taskDetails!['longitude'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Coordinates: ${_taskDetails!['latitude']}, ${_taskDetails!['longitude']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openMap,
              icon: const Icon(Icons.map),
              label: const Text('Open in Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              'Reported',
              _getFormattedDate(_taskDetails!['timestamp']),
              Icons.report_outlined,
              Colors.red,
              isFirst: true,
              isDone: true,
            ),
            _buildTimelineItem(
              'Assigned',
              _getFormattedDate(_taskDetails!['assignedAt']),
              Icons.assignment,
              Colors.orange,
              isDone: true,
            ),
            _buildTimelineItem(
              'Started',
              _taskDetails!['startedAt'] != null
                  ? _getFormattedDate(_taskDetails!['startedAt'])
                  : 'Not yet started',
              Icons.play_circle_outline,
              Colors.blue,
              isDone: _taskDetails!['startedAt'] != null,
            ),
            _buildTimelineItem(
              'Completed',
              _taskDetails!['completedAt'] != null
                  ? _getFormattedDate(_taskDetails!['completedAt'])
                  : 'Not yet completed',
              Icons.check_circle_outline,
              Colors.green,
              isLast: true,
              isDone: _taskDetails!['completedAt'] != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
    bool isDone = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? color : Colors.grey[300],
              ),
              child: Icon(
                icon,
                size: 15,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isDone ? color : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDone ? color : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportedImage() {
    final String? imageBase64 = _taskDetails!['imageBase64'];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.image, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Reported Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (imageBase64 != null && imageBase64.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(imageBase64),
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No image available'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedImage() {
    final String? imageBase64 = _taskDetails!['completedImageBase64'];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.image, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Completed Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (imageBase64 != null && imageBase64.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(imageBase64),
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No completed image available'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.note_add, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Worker Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add notes about this task...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveNotes,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Notes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}