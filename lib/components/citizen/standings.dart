import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Standings extends StatefulWidget {
  const Standings({super.key});

  @override
  State<Standings> createState() => _StandingsState();
}

class _StandingsState extends State<Standings> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> userRankings = [];

  @override
  void initState() {
    super.initState();
    _fetchUserRankings();
  }

  Future<void> _fetchUserRankings() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get all waste reports grouped by userId
      final reportsSnapshot = await _firestore.collection('waste_reports').get();

      // Map to store user data: userId -> {completedReports, totalReports, username}
      Map<String, Map<String, dynamic>> userStats = {};

      // Process all waste reports
      for (var doc in reportsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;
        final status = data['status'] as String;

        // Initialize user stats if not already present
        if (!userStats.containsKey(userId)) {
          userStats[userId] = {
            'completedReports': 0,
            'totalReports': 0,
            'userId': userId,
            'username': 'Unknown User', // Default name, will be updated later
            'role': '', // Will be updated when we fetch user info
          };
        }

        // Update stats
        userStats[userId]!['totalReports'] = (userStats[userId]!['totalReports'] as int) + 1;

        // Count completed reports
        if (status == 'completed') {
          userStats[userId]!['completedReports'] = (userStats[userId]!['completedReports'] as int) + 1;
        }
      }

      // Get user info for all users and filter only citizens
      List<Map<String, dynamic>> citizenRankings = [];

      for (String userId in userStats.keys) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData != null) {
              // Update user info
              if (userData.containsKey('username')) {
                userStats[userId]!['username'] = userData['username'];
              }

              // Check if user is a citizen and only include citizens
              if (userData.containsKey('role') && userData['role'] == 'Citizen') {
                userStats[userId]!['role'] = userData['role'];
                citizenRankings.add(userStats[userId]!);
              }
            }
          }
        } catch (e) {
          print('Error fetching user info for $userId: $e');
        }
      }

      // Sort by completed reports (descending) and then by total reports (ascending)
      citizenRankings.sort((a, b) {
        int completedComparison = (b['completedReports'] as int).compareTo(a['completedReports'] as int);
        if (completedComparison != 0) {
          return completedComparison; // Sort by completed reports first
        }
        // If same number of completed reports, prioritize the one with fewer total reports
        return (a['totalReports'] as int).compareTo(b['totalReports'] as int);
      });

      // Add rank to each user
      for (int i = 0; i < citizenRankings.length; i++) {
        citizenRankings[i]['rank'] = i + 1;
      }

      setState(() {
        userRankings = citizenRankings;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching rankings: $e');
      setState(() {
        isLoading = false;
      });
      _showSnackBar('Error loading standings: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _getUserAchievementLevel(int completedReports) {
    if (completedReports >= 20) return 'Earth Guardian';
    if (completedReports >= 15) return 'Eco Warrior';
    if (completedReports >= 10) return 'Community Hero';
    if (completedReports >= 5) return 'Active Citizen';
    return 'Beginner';
  }

  Color _getAchievementColor(int completedReports) {
    if (completedReports >= 20) return Colors.teal;
    if (completedReports >= 15) return Colors.green;
    if (completedReports >= 10) return Colors.blue;
    if (completedReports >= 5) return Colors.amber;
    return Colors.grey;
  }
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.lightGreenAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchUserRankings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lightGreenAccent.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Urban Heroes Podium',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Top citizens making our city cleaner',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Top 3 users - displayed in podium format with hexagonal frames
              if (userRankings.isNotEmpty)
                Container(
                  height: 280,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Podium base
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                            ),
                          ),
                        ),
                      ),
                      
                      // Second place (left)
                      if (userRankings.length >= 2)
                        Positioned(
                          bottom: 40,
                          left: MediaQuery.of(context).size.width * 0.10,
                          child: _buildHexagonalUserCard(userRankings[1], 2, Colors.green.shade500),
                        ),
                      
                      // First place (center - tallest)
                      Positioned(
                        bottom: 65,
                        child: _buildHexagonalUserCard(userRankings[0], 1, Colors.amber),
                      ),
                      
                      // Third place (right)
                      if (userRankings.length >= 3)
                        Positioned(
                          bottom: 10,
                          right: MediaQuery.of(context).size.width * 0.10,
                          child: _buildHexagonalUserCard(userRankings[2], 3, Colors.purple),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Divider with label
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Complete Rankings', style: TextStyle(color: Colors.black54)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Full list of users
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: userRankings.length,
                itemBuilder: (context, index) {
                  final user = userRankings[index];
                  final bool isCurrentUser = currentUser != null &&
                      user['userId'] == currentUser.uid;

                  // Calculate completion percentage safely
                  final int totalReports = user['totalReports'] as int;
                  final int completedReports = user['completedReports'] as int;
                  final double completionPercentage = totalReports > 0
                      ? (completedReports / totalReports * 100)
                      : 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    elevation: isCurrentUser ? 3 : 1,
                    color: isCurrentUser
                        ? Colors.lightGreenAccent.withOpacity(0.2)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isCurrentUser
                          ? const BorderSide(color: Colors.lightGreenAccent, width: 2)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Text(
                          '${user['rank']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      title: Text(
                        user['username'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completed: ${user['completedReports']} / ${user['totalReports']} reports',
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getAchievementColor(user['completedReports']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _getAchievementColor(user['completedReports']),
                              ),
                            ),
                            child: Text(
                              _getUserAchievementLevel(user['completedReports']),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getAchievementColor(user['completedReports']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${completionPercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text('success rate'),
                        ],
                      ),
                    ),
                  );
                },
              ),

              if (userRankings.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No citizen data available yet. Start reporting issues to be on the leaderboard!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  // _buildTopUserCard has been replaced with _buildHexagonalUserCard

  Widget _buildHexagonalUserCard(Map<String, dynamic> user, int rank, Color medalColor) {
    String rankText = rank.toString();
    
    return Column(
      children: [
        // Rank indicator at the top
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: medalColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: medalColor.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '#$rankText',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        // Hexagonal avatar frame
        SizedBox(
          width: 100,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hexagon shape
              CustomPaint(
                size: const Size(95, 110),
                painter: HexagonPainter(
                  color: medalColor,
                  strokeColor: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              
              // User avatar
              Positioned(
                top: 15,
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(
                    Icons.person,
                    color: Colors.grey,
                    size: 30,
                  ),
                ),
              ),
              
              // Username
              Positioned(
                bottom: 15,
                child: Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    user['username'],
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Achievement badge
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${user['completedReports']} Reports',
                style: TextStyle(
                  fontSize: 12,
                  color: _getAchievementColor(user['completedReports']),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom painter for hexagon shape
class HexagonPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;
  final double strokeWidth;

  HexagonPainter({
    required this.color, 
    required this.strokeColor, 
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final Paint strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    final Path path = Path();
    final double width = size.width;
    final double height = size.height;
    
    // Calculate hexagon points
    final double centerX = width / 2;
    final double centerY = height / 2;
    final double radius = width / 2;
    
    // Create hexagon path starting from top
    path.moveTo(centerX, centerY - radius); // Top
    path.lineTo(centerX + radius * 0.866, centerY - radius * 0.5); // Top right
    path.lineTo(centerX + radius * 0.866, centerY + radius * 0.5); // Bottom right
    path.lineTo(centerX, centerY + radius); // Bottom
    path.lineTo(centerX - radius * 0.866, centerY + radius * 0.5); // Bottom left
    path.lineTo(centerX - radius * 0.866, centerY - radius * 0.5); // Top left
    path.close();
    
    // Draw filled hexagon and stroke
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}