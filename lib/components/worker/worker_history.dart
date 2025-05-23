import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({super.key});

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _selectedFilter = 'All Time';
  final List<String> _filterOptions = [
    'Today',
    'This Week',
    'This Month',
    'All Time'
  ];

  // Statistics
  final int _totalTasksCompleted = 15;
  final int _totalTasksAssigned = 20;
  final int _tasksInProgress = 3;
  final double _completionRate = 75.0;
  final double _averageResponseTime = 25.0;
  final double _userRating = 4.7;
  final double _hoursWorked = 38.5;
  List<Map<String, dynamic>> _weeklyStats = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() {
    setState(() {
      _isLoading = true;
    });
    
    // Weekly statistics
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    _weeklyStats = [
      {'day': 'Mon', 'count': 4, 'inProgress': 1, 'completed': 3},
      {'day': 'Tue', 'count': 3, 'inProgress': 1, 'completed': 2},
      {'day': 'Wed', 'count': 5, 'inProgress': 2, 'completed': 3},
      {'day': 'Thu', 'count': 3, 'inProgress': 0, 'completed': 3},
      {'day': 'Fri', 'count': 0, 'inProgress': 0, 'completed': 0},
      {'day': 'Sat', 'count': 0, 'inProgress': 0, 'completed': 0},
      {'day': 'Sun', 'count': 0, 'inProgress': 0, 'completed': 0},
    ];

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Statistics'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
                _loadStatistics();
              });
            },
            itemBuilder: (context) {
              return _filterOptions.map((filter) {
                return PopupMenuItem(
                  value: filter,
                  child: Row(
                    children: [
                      if (_selectedFilter == filter)
                        const Icon(Icons.check, color: Colors.blue, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(filter),
                    ],
                  ),
                );
              }).toList();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatistics(),
                  _buildWeeklyChart(),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
    );
  }

  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Statistics ($_selectedFilter)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Task Status Section
          Row(
            children: [
              _buildStatCard(
                'Total\nAssigned',
                _totalTasksAssigned.toString(),
                Icons.assignment,
                Colors.blue,
              ),
              _buildStatCard(
                'In\nProgress',
                _tasksInProgress.toString(),
                Icons.pending_actions,
                Colors.orange,
              ),
              _buildStatCard(
                'Tasks\nCompleted',
                _totalTasksCompleted.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Performance Metrics Section
          Row(
            children: [
              _buildStatCard(
                'Completion\nRate',
                '${_completionRate.toStringAsFixed(1)}%',
                Icons.analytics,
                Colors.purple,
              ),
              _buildStatCard(
                'Hours\nWorked',
                '${_hoursWorked.toStringAsFixed(1)}h',
                Icons.access_time,
                Colors.teal,
              ),
              _buildStatCard(
                'Response\nTime',
                '${_averageResponseTime.toStringAsFixed(1)}m',
                Icons.speed,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tasks Completed This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _weeklyStats.isEmpty 
                    ? 10 
                    : (_weeklyStats.map((s) => s['count'] as int).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex >= _weeklyStats.length) return null;
                      return BarTooltipItem(
                        '${_weeklyStats[groupIndex]['day']}: ${_weeklyStats[groupIndex]['count']} tasks',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _weeklyStats.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _weeklyStats[index]['day'] as String,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return const Text('0');
                        }
                        if (value % 2 == 0) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 2,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: _weeklyStats.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value['count'] as int).toDouble(),
                        color: Colors.blue.withOpacity(0.7),
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}