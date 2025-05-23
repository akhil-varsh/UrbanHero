import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerProfile {
  final String id;
  final String userId;
  final String username;
  final String email;
  final String? phone;
  final String? location;
  final String? profileImageBase64;
  final String availability;
  final String specialization;
  final List<String> skills;
  final int experienceYears;
  final double rating;
  final bool isProfileComplete;
  final DateTime? lastUpdated;
  final int completedTasks;
  final int pendingTasks;

  WorkerProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    this.phone,
    this.location,
    this.profileImageBase64,
    required this.availability,
    required this.specialization,
    required this.skills,
    required this.experienceYears,
    this.rating = 0.0,
    this.isProfileComplete = false,
    this.lastUpdated,
    this.completedTasks = 0,
    this.pendingTasks = 0,
  });

  factory WorkerProfile.fromMap(Map<String, dynamic> map, String documentId) {
    return WorkerProfile(
      id: documentId,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      location: map['location'],
      profileImageBase64: map['profileImageBase64'],
      availability: map['availability'] ?? 'Available',
      specialization: map['specialization'] ?? 'General',
      skills: List<String>.from(map['skills'] ?? []),
      experienceYears: map['experienceYears'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      isProfileComplete: map['isProfileComplete'] ?? false,
      lastUpdated: map['lastUpdated'] != null 
          ? (map['lastUpdated'] as Timestamp).toDate() 
          : null,
      completedTasks: map['completedTasks'] ?? 0,
      pendingTasks: map['pendingTasks'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'phone': phone,
      'location': location,
      'profileImageBase64': profileImageBase64,
      'availability': availability,
      'specialization': specialization,
      'skills': skills,
      'experienceYears': experienceYears,
      'rating': rating,
      'isProfileComplete': isProfileComplete,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'completedTasks': completedTasks,
      'pendingTasks': pendingTasks,
    };
  }

  WorkerProfile copyWith({
    String? id,
    String? userId,
    String? username,
    String? email,
    String? phone,
    String? location,
    String? profileImageBase64,
    String? availability,
    String? specialization,
    List<String>? skills,
    int? experienceYears,
    double? rating,
    bool? isProfileComplete,
    DateTime? lastUpdated,
    int? completedTasks,
    int? pendingTasks,
  }) {
    return WorkerProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      availability: availability ?? this.availability,
      specialization: specialization ?? this.specialization,
      skills: skills ?? this.skills,
      experienceYears: experienceYears ?? this.experienceYears,
      rating: rating ?? this.rating,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      completedTasks: completedTasks ?? this.completedTasks,
      pendingTasks: pendingTasks ?? this.pendingTasks,
    );
  }
}