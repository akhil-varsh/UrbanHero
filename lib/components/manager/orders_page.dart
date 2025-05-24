import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:url_launcher/url_launcher.dart'; // Added for launching URLs

class ManagerOrdersPage extends StatefulWidget {
  const ManagerOrdersPage({super.key});

  @override
  _ManagerOrdersPageState createState() => _ManagerOrdersPageState();
}

class _ManagerOrdersPageState extends State<ManagerOrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatusFilter = 'All'; // Default filter
  final List<String> _statusFilterOptions = ['All', 'Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('purchases').doc(orderId).update({
        'orderStatus': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $orderId status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order status: $e')),
      );
      print('Error updating order status: $e');
    }
  }

  void _showUpdateStatusDialog(BuildContext context, String orderId, String currentStatus) {
    String selectedStatus = currentStatus; // Default to current status
    final List<String> statusOptions = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Update Order Status (ID: $orderId)'),
          content: StatefulBuilder( // Use StatefulBuilder for DropdownButton
            builder: (BuildContext context, StateSetter setState) {
              return DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Order Status'),
                items: statusOptions.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedStatus = newValue;
                    });
                  }
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Update Status'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _updateOrderStatus(orderId, selectedStatus);
              },
            ),
          ],
        );
      },
    );
  }

  // Method to get the stream based on the selected filter
  Stream<QuerySnapshot> _getOrdersStream() {
    Query query = _firestore.collection('purchases').orderBy('timestamp', descending: true);
    if (_selectedStatusFilter != 'All') {
      query = query.where('orderStatus', isEqualTo: _selectedStatusFilter);
    }
    return query.snapshots();
  }

  void _showOrderDetailsDialog(BuildContext context, String orderId, Map<String, dynamic> data) {
    final String productName = data['productName'] ?? 'N/A';
    final int productPrice = data['productPrice'] ?? 0;
    final Timestamp timestamp = data['timestamp'] as Timestamp? ?? Timestamp.now();
    final String orderStatus = data['orderStatus'] ?? 'Pending';
    final String userAddress = data['userAddress'] ?? 'N/A';
    final String userEmail = data['userEmail'] ?? 'N/A';
    final String userId = data['userId'] ?? 'N/A';
    final GeoPoint? userLocation = data['userLocation'] as GeoPoint?;
    final String userPhone = data['userPhone'] ?? 'N/A';
    final String username = data['username'] ?? 'N/A'; // Assuming 'username' is the field key

    final String formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Order Details (ID: $orderId)'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('Product Name:', productName),
                _buildDetailRow('Price:', '$productPrice points'),
                _buildDetailRow('Ordered On:', formattedDate),
                _buildDetailRow('Status:', orderStatus, statusColor: _getStatusColor(orderStatus)),
                const Divider(),
                _buildDetailRow('User ID:', userId),
                _buildDetailRow('Username:', username),
                _buildDetailRow('Email:', userEmail),
                _buildDetailRow('Phone:', userPhone),
                _buildDetailRow('Address:', userAddress),
                if (userLocation != null) ...[
                  _buildDetailRow('Location:', 'Lat: ${userLocation.latitude.toStringAsFixed(5)}, Lng: ${userLocation.longitude.toStringAsFixed(5)}'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    onPressed: () {
                      _launchMapsUrl(userLocation.latitude, userLocation.longitude);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Update Status'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close details dialog
                _showUpdateStatusDialog(context, orderId, orderStatus); // Show update status dialog
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: statusColor != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                : Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMapsUrl(double lat, double lon) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lon";
    // ignore: deprecated_member_use
    if (await canLaunch(googleMapsUrl)) {
      // ignore: deprecated_member_use
      await launch(googleMapsUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch maps for $lat,$lon')),
      );
      print('Could not launch $googleMapsUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Product Orders'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column( // Wrap body in a Column to add the filter dropdown
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedStatusFilter,
              decoration: InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _statusFilterOptions.map((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedStatusFilter = newValue;
                  });
                }
              },
            ),
          ),
          Expanded( // Make the StreamBuilder take the remaining space
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(), // Use the method to get the stream
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No orders found.'));
                }

                final orders = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final data = order.data() as Map<String, dynamic>;
                    final String orderId = order.id;
                    final String productName = data['productName'] ?? 'N/A';
                    final int productPrice = data['productPrice'] ?? 0;
                    final String userId = data['userId'] ?? 'N/A';
                    final Timestamp timestamp = data['timestamp'] as Timestamp? ?? Timestamp.now();
                    final String orderStatus = data['orderStatus'] ?? 'Pending';

                    // Format the timestamp
                    final String formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        title: Text(
                          'Order ID: $orderId',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Product: $productName', style: const TextStyle(fontSize: 14)),
                            Text('Ordered On: $formattedDate', style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text(
                                  'Status: ',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(orderStatus),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    orderStatus,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.deepPurple, size: 16),
                        isThreeLine: true,
                        onTap: () {
                          _showOrderDetailsDialog(context, orderId, data);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orangeAccent;
      case 'Processing':
        return Colors.blueAccent;
      case 'Shipped':
        return Colors.lightGreen;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
