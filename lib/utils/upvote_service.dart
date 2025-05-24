import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UpvoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add an upvote to a report
  Future<bool> upvoteReport(String reportId) async {
    try {
      // Get the current user
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Check if user has already upvoted this report
      final upvotesRef = _firestore.collection('report_upvotes');
      final query = await upvotesRef
          .where('reportId', isEqualTo: reportId)
          .where('userId', isEqualTo: user.uid)
          .get();

      // If user has already upvoted, return false
      if (query.docs.isNotEmpty) {
        return false;
      }

      // Add the upvote
      await upvotesRef.add({
        'reportId': reportId,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update upvote count in the report document
      final reportRef = _firestore.collection('waste_reports').doc(reportId);
      
      // Transaction to update upvote count safely
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(reportRef);
        if (!snapshot.exists) {
          throw Exception("Report does not exist!");
        }
        
        var data = snapshot.data() as Map<String, dynamic>;
        int upvoteCount = data['upvoteCount'] ?? 0;
        
        transaction.update(reportRef, {'upvoteCount': upvoteCount + 1});
      });

      return true;
    } catch (e) {
      print('Error upvoting report: $e');
      return false;
    }
  }

  // Check if the current user has upvoted a specific report
  Future<bool> hasUserUpvoted(String reportId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final upvotesRef = _firestore.collection('report_upvotes');
      final query = await upvotesRef
          .where('reportId', isEqualTo: reportId)
          .where('userId', isEqualTo: user.uid)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if user has upvoted: $e');
      return false;
    }
  }

  // Get the upvote count for a specific report
  Future<int> getUpvoteCount(String reportId) async {
    try {
      final upvotesRef = _firestore.collection('report_upvotes');
      final query = await upvotesRef
          .where('reportId', isEqualTo: reportId)
          .get();

      return query.docs.length;
    } catch (e) {
      print('Error getting upvote count: $e');
      return 0;
    }
  }

  // Get a stream of upvote count for a specific report
  Stream<int> upvoteCountStream(String reportId) {
    return _firestore
        .collection('waste_reports')
        .doc(reportId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return 0;
      }
      final data = snapshot.data() as Map<String, dynamic>;
      return data['upvoteCount'] ?? 0;
    });
  }
}
