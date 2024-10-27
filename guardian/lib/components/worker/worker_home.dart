import 'package:flutter/material.dart';

class WorkerHomeScreen extends StatelessWidget {
  final List<WasteReport> tasks = [
    WasteReport(id: '1', status: 'pending', imageUrl: 'https://static.toiimg.com/thumb/msid-92374253,width-1280,height-720,imgsize-1588598,resizemode-6,overlay-toi_sw,pt-32,y_pad-40/photo.jpg', location: Location(latitude: 12.9716, longitude: 77.5946)),
    WasteReport(id: '2', status: 'in_progress', imageUrl: 'https://assets.thehansindia.com/h-upload/2019/09/13/215926-central-ghmc.webp', location: Location(latitude: 12.2958, longitude: 76.6394)),
    WasteReport(id: '3', status: 'completed', imageUrl: 'https://hyderabadmail.com/wp-content/uploads/2024/06/Hyderabad-Mail-spurs-GHMC-into-action-Diamond-City-Colony-sees-regular-garbage-cleanup.jpg', location: Location(latitude: 13.0827, longitude: 80.2707)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Worker Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
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
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/profile'); // Navigate to profile
              },
            ),
            ListTile(
              leading: Icon(Icons.pending),
              title: Text('Pending Tasks'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/pending_tasks'); // Navigate to pending tasks
              },
            ),
            ListTile(
              leading: Icon(Icons.check_circle),
              title: Text('Completed Tasks'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/completed_tasks'); // Navigate to completed tasks
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Task #${task.id}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(task.status),
              ],
            ),
            SizedBox(height: 8),
            Image.network(
              task.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            SizedBox(height: 8),
            Text('Location: ${task.location.latitude}, ${task.location.longitude}'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'in_progress':
        color = Colors.blue;
        label = 'In Progress';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
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
  final String status;
  final String imageUrl;
  final Location location;

  WasteReport({required this.id, required this.status, required this.imageUrl, required this.location});
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});
}


// import 'package:flutter/material.dart';
// import '../../../services/waste_service.dart';
//
// class WorkerHomeScreen extends StatelessWidget {
//   final WasteService _wasteService = WasteService();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Worker Dashboard'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.person),
//             onPressed: () => Navigator.pushNamed(context, '/profile'),
//           ),
//         ],
//       ),
//       body: StreamBuilder<List<WasteReport>>(
//         stream: _wasteService.getWorkerTasks('current_worker_id'), // Replace with actual ID
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }
//
//           if (!snapshot.hasData) {
//             return Center(child: CircularProgressIndicator());
//           }
//
//           final tasks = snapshot.data!;
//           return ListView.builder(
//             itemCount: tasks.length,
//             itemBuilder: (context, index) {
//               final task = tasks[index];
//               return TaskCard(task: task);
//             },
//           );
//         },
//       ),
//     );
//   }
// }
//
// class TaskCard extends StatelessWidget {
//   final WasteReport task;
//
//   const TaskCard({Key? key, required this.task}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: EdgeInsets.all(8),
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     'Task #${task.id}',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 _buildStatusChip(task.status),
//               ],
//             ),
//             SizedBox(height: 8),
//             Image.network(
//               task.imageUrl,
//               height: 200,
//               width: double.infinity,
//               fit: BoxFit.cover,
//             ),
//             SizedBox(height: 8),
//             Text('Location: ${task.location.latitude}, ${task.location.longitude}'),
//             SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: () => _updateStatus(context, 'in_progress'),
//                   child: Text('Start'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () => _updateStatus(context, 'completed'),
//                   child: Text('Complete'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildStatusChip(String status) {
//     Color color;
//     String label;
//
//     switch (status) {
//       case 'pending':
//         color = Colors.orange;
//         label = 'Pending';
//         break;
//       case 'in_progress':
//         color = Colors.blue;
//         label = 'In Progress';
//         break;
//       case 'completed':
//         color = Colors.green;
//         label = 'Completed';
//         break;
//       default:
//         color = Colors.grey;
//         label = 'Unknown';
//     }
//
//     return Chip(
//       label: Text(label),
//       backgroundColor: color.withOpacity(0.2),
//       labelStyle: TextStyle(color: color),
//     );
//   }
//
//   Future<void> _updateStatus(BuildContext context, String status) async {
//     try {
//       final wasteService = WasteService();
//       await wasteService.updateWorkStatus(
//         reportId: task.id,
//         status: status,
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Status updated successfully')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to update status')),
//       );
//     }
//   }
// }