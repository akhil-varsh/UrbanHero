import 'package:cloud_firestore/cloud_firestore.dart';

class ReportUpvote {
  final String id;
  final String reportId;
  final String userId;
  final DateTime timestamp;

  ReportUpvote({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'userId': userId,
      'timestamp': timestamp,
    };
  }

  factory ReportUpvote.fromMap(Map<String, dynamic> map, String documentId) {
    return ReportUpvote(
      id: documentId,
      reportId: map['reportId'] ?? '',
      userId: map['userId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
