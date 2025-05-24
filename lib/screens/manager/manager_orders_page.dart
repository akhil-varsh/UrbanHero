import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerOrdersPage extends StatefulWidget {
  const ManagerOrdersPage({super.key});

  @override
  _ManagerOrdersPageState createState() => _ManagerOrdersPageState();
}

class _ManagerOrdersPageState extends State<ManagerOrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('purchases').doc(orderId).update({
        'orderStatus': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('purchases').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading orders.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: orders.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Number of columns
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 0.75, // Adjust as needed for card height
            ),
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final String productName = data['productName'] ?? 'N/A';
              final int productPrice = data['productPrice'] ?? 0;
              // final String userId = data['userId'] ?? 'N/A'; // Keep if needed for direct reference
              final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
              final String orderStatus = data['orderStatus'] ?? 'Pending';

              // New fields from the purchases collection
              final String userName = data['userName'] ?? 'N/A';
              final String userEmail = data['userEmail'] ?? 'N/A';
              final String userAddress = data['userAddress'] ?? 'N/A';
              final String userPhone = data['userPhone'] ?? 'N/A';
              final GeoPoint? userLocation = data['userLocation'] as GeoPoint?;


              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Product: $productName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Price: $productPrice Pts', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('User: $userName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      Text('Email: $userEmail', style: const TextStyle(fontSize: 16)),
                      Text('Phone: $userPhone', style: const TextStyle(fontSize: 16)),
                      Text('Address: $userAddress', style: const TextStyle(fontSize: 16)),
                      if (userLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Location: Lat: ${userLocation.latitude.toStringAsFixed(5)}, Lng: ${userLocation.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(fontSize: 16)
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text('Ordered At: ${timestamp.toDate().toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status: $orderStatus', style: TextStyle(fontWeight: FontWeight.bold, color: orderStatus == 'Pending' ? Colors.orange : Colors.green)),
                          PopupMenuButton<String>(
                            onSelected: (String newStatus) {
                              _updateOrderStatus(order.id, newStatus);
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'Pending',
                                child: Text('Pending'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Processing',
                                child: Text('Processing'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Shipped',
                                child: Text('Shipped'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Delivered',
                                child: Text('Delivered'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Cancelled',
                                child: Text('Cancelled'),
                              ),
                            ],
                            child: const Icon(Icons.more_vert),
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
      ),
    );
  }
}
