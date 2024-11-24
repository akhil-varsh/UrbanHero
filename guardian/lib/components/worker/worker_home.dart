import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerHomeScreen extends StatefulWidget {
  @override
  _WorkerHomeScreenState createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<WasteReport> tasks = [];

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  // Fetch the tasks (waste reports) from Firestore
  Future<void> fetchTasks() async {
    try {
      final snapshot = await _firestore.collection('waste_reports').get();
      setState(() {
        tasks = snapshot.docs.map((doc) {
          return WasteReport(
            id: doc.id,
            description: doc['description'],
            imageBase64: doc['imageBase64'],
            location: doc['location'],
            timestamp: doc['timestamp'].toDate(),
            wasteSize: doc['wasteSize'],
          );
        }).toList();
      });
    } catch (e) {
      print('Error fetching tasks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Worker Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profilew'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profilew');
              },
            ),
            ListTile(
              leading: Icon(Icons.pending),
              title: Text('My Performance'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/perform');
              },
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskCard(task: task);
        },
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final WasteReport task;

  const TaskCard({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task #${task.id}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Description: ${task.description}'),
            SizedBox(height: 8),
            _buildImage(task.imageBase64),
            SizedBox(height: 8),
            Text('Location: ${task.location}'),
            SizedBox(height: 8),
            Text('Waste Size: ${task.wasteSize}'),
            SizedBox(height: 8),
            Text('Reported At: ${task.timestamp}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _updateStatus(context, 'in_progress'),
              child: Text('Start'),
            ),
            ElevatedButton(
              onPressed: () => _updateStatus(context, 'completed'),
              child: Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageBase64) {
    if (imageBase64.isNotEmpty) {
      return Image.memory(
        Base64Decoder().convert(imageBase64),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey[300],
        child: Center(child: Text('No Image Available')),
      );
    }
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      // Here you would update the status with the WasteService
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status')),
      );
    }
  }
}

// Sample classes for WasteReport and Location
class WasteReport {
  final String id;
  final String description;
  final String imageBase64;
  final String location;
  final DateTime timestamp;
  final String wasteSize;

  WasteReport({
    required this.id,
    required this.description,
    required this.imageBase64,
    required this.location,
    required this.timestamp,
    required this.wasteSize,
  });
}
