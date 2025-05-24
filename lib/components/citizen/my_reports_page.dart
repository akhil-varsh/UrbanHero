import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:UrbanHero/utils/upvote_service.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UpvoteService _upvoteService = UpvoteService();
  
  String? _userId;
  
  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Reports"),
          backgroundColor: Colors.yellowAccent,
        ),
        body: const Center(
          child: Text("Please log in to view your reports"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports"),
        backgroundColor: Colors.yellowAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('waste_reports')
            .where('userId', isEqualTo: _userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error fetching data: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.report_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "You haven't reported any issues yet.",
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "When you submit a report, it will appear here.",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          var issues = snapshot.data!.docs;
          
          return ListView.builder(
            itemCount: issues.length,
            itemBuilder: (context, index) {
              var issueData = issues[index].data() as Map<String, dynamic>;
              var issueId = issues[index].id;
              var status = issueData['status'] ?? 'Pending';
              
              Color statusColor;
              switch (status) {
                case 'Completed':
                  statusColor = Colors.green;
                  break;
                case 'In Progress':
                  statusColor = Colors.orange;
                  break;
                case 'Assigned':
                  statusColor = Colors.blue;
                  break;
                default:
                  statusColor = Colors.red;
              }

              return Card(
                margin: const EdgeInsets.all(8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.only(right: 12, top: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    
                    // Image Section
                    if (issueData.containsKey('imageBase64') && (issueData['imageBase64'] as String).isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(issueData['imageBase64']),
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 180,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Waste type and upvote count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(
                                  issueData['wasteType'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.blue.shade700,
                              ),
                              
                              // Upvote counter
                              StreamBuilder<int>(
                                stream: _upvoteService.upvoteCountStream(issueId),
                                builder: (context, upvoteSnapshot) {
                                  final upvotes = upvoteSnapshot.data ?? issueData['upvoteCount'] ?? 0;
                                  return Row(
                                    children: [
                                      Text(
                                        '$upvotes',
                                        style: TextStyle(
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold,
                                          color: upvotes > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.thumb_up,
                                        size: 16,
                                        color: upvotes > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Description
                          Text(
                            issueData['description'] ?? 'No description',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Details
                          Text("Waste Size: ${issueData['wasteSize'] ?? 'Unknown'}"),
                          Text(
                            "Location: ${issueData['formattedAddress'] ?? issueData['location'] ?? 'Unknown'}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Date
                          Text(
                            "Reported on: ${issueData['timestamp'] != null ? (issueData['timestamp'] as Timestamp).toDate().toString().substring(0, 16) : 'Unknown'}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
