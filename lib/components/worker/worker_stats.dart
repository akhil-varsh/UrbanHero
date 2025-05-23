import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

class WorkerStatsScreen extends StatefulWidget {
  const WorkerStatsScreen({super.key});

  @override
  State<WorkerStatsScreen> createState() => _WorkerStatsScreenState();
}

class _WorkerStatsScreenState extends State<WorkerStatsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _taskSubscription;
  StreamSubscription? _reportSubscription;

  bool _isLoading = true;
  String _selectedPeriod = 'This Month';
  final List<String> _timePeriods = ['This Week', 'This Month', 'This Year', 'All Time'];

  int _tasksCompleted = 0;
  double _avgResponseTime = 0;
  double _userRating = 0;
  int _areasCovered = 0;
  double _hoursWorked = 0;

  List<Map<String, dynamic>> _tasksByDayData = [];
  List<Map<String, dynamic>> _responseTimeData = [];
  Map<String, double> _wasteTypeData = {};

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    _reportSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('User not authenticated');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    DateTime startDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'All Time':
      default:
        startDate = DateTime(2000);
    }

    // Listen to waste reports in real-time
    _taskSubscription?.cancel();
    _taskSubscription = _firestore
        .collection('waste_reports')
        .where('assignedWorker', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .snapshots()
        .listen((snapshot) {
          _processTaskData(snapshot.docs);
        });

    // Listen to worker reports in real-time
    _reportSubscription?.cancel();
    _reportSubscription = _firestore
        .collection('worker_reports')
        .where('workerId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .snapshots()
        .listen((snapshot) {
          _processReportData(snapshot.docs);
        });
  }

  void _processTaskData(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    
    double totalResponseTime = 0;
    int responseTimes = 0;
    Set<String> areas = {};
    Map<String, int> wasteTypeCount = {};
    Map<String, int> tasksByDay = {};
    List<double> responseTimes24h = [];

    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      String wasteSize = data['wasteSize'] ?? 'Unknown';
      wasteTypeCount[wasteSize] = (wasteTypeCount[wasteSize] ?? 0) + 1;

      if (data['location'] != null) {
        areas.add(data['location'].toString().split(',').first);
      }

      if (data['timestamp'] != null && data['startedAt'] != null) {
        DateTime reportTime = (data['timestamp'] as Timestamp).toDate();
        DateTime startTime = (data['startedAt'] as Timestamp).toDate();
        int responseMinutes = startTime.difference(reportTime).inMinutes;

        totalResponseTime += responseMinutes;
        responseTimes++;

        DateTime completed = (data['completedAt'] as Timestamp).toDate();
        String dayKey = DateFormat('yyyy-MM-dd').format(completed);
        tasksByDay[dayKey] = (tasksByDay[dayKey] ?? 0) + 1;

        if (completed.isAfter(now.subtract(const Duration(days: 7)))) {
          responseTimes24h.add(responseMinutes.toDouble());
        }
      }
    }

    List<Map<String, dynamic>> tasksByDayData = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      final dayLabel = DateFormat('E').format(date);
      tasksByDayData.add({
        'day': dayLabel,
        'count': tasksByDay[dayKey] ?? 0,
      });
    }

    Map<String, double> wasteTypeData = {};
    wasteTypeCount.forEach((key, value) {
      wasteTypeData[key] = value.toDouble();
    });

    List<Map<String, dynamic>> responseTimeData = [];
    responseTimes24h.sort();
    int step = responseTimes24h.length > 20 ? (responseTimes24h.length / 20).ceil() : 1;
    for (int i = 0; i < responseTimes24h.length; i += step) {
      if (i < responseTimes24h.length) {
        responseTimeData.add({
          'index': responseTimeData.length,
          'time': responseTimes24h[i],
        });
      }
    }

    setState(() {
      _tasksCompleted = docs.length;
      _avgResponseTime = responseTimes > 0 ? totalResponseTime / responseTimes : 0;
      _areasCovered = areas.length;
      _tasksByDayData = tasksByDayData;
      _responseTimeData = responseTimeData;
      _wasteTypeData = wasteTypeData;
      _isLoading = false;
    });
  }

  void _processReportData(List<QueryDocumentSnapshot> docs) {
    double totalHours = 0;
    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      totalHours += (data['hoursWorked'] ?? 0).toDouble();
    }

    setState(() {
      _hoursWorked = totalHours;
    });
  }

  Future<void> _fetchPerformanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        print('User not authenticated');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      DateTime startDate;
      final now = DateTime.now();

      switch (_selectedPeriod) {
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        case 'All Time':
        default:
          startDate = DateTime(2000);
      }

      final QuerySnapshot taskSnapshot = await _firestore
          .collection('waste_reports')
          .where('assignedWorker', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final tasksCompleted = taskSnapshot.docs.length;
      double totalResponseTime = 0;
      int responseTimes = 0;
      Set<String> areas = {};
      Map<String, int> wasteTypeCount = {};
      Map<String, int> tasksByDay = {};
      List<double> responseTimes24h = [];

      for (var doc in taskSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        String wasteSize = data['wasteSize'] ?? 'Unknown';
        wasteTypeCount[wasteSize] = (wasteTypeCount[wasteSize] ?? 0) + 1;

        if (data['location'] != null) {
          areas.add(data['location'].toString().split(',').first);
        }

        if (data['timestamp'] != null && data['startedAt'] != null) {
          DateTime reportTime = (data['timestamp'] as Timestamp).toDate();
          DateTime startTime = (data['startedAt'] as Timestamp).toDate();
          int responseMinutes = startTime.difference(reportTime).inMinutes;

          totalResponseTime += responseMinutes;
          responseTimes++;

          DateTime completed = (data['completedAt'] as Timestamp).toDate();
          String dayKey = DateFormat('yyyy-MM-dd').format(completed);
          tasksByDay[dayKey] = (tasksByDay[dayKey] ?? 0) + 1;

          if (completed.isAfter(now.subtract(const Duration(days: 7)))) {
            responseTimes24h.add(responseMinutes.toDouble());
          }
        }
      }

      final QuerySnapshot reportSnapshot = await _firestore
          .collection('worker_reports')
          .where('workerId', isEqualTo: uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      double totalHours = 0;
      for (var doc in reportSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalHours += (data['hoursWorked'] ?? 0).toDouble();
      }

      List<Map<String, dynamic>> tasksByDayData = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        final dayLabel = DateFormat('E').format(date);
        tasksByDayData.add({
          'day': dayLabel,
          'count': tasksByDay[dayKey] ?? 0,
        });
      }

      Map<String, double> wasteTypeData = {};
      wasteTypeCount.forEach((key, value) {
        wasteTypeData[key] = value.toDouble();
      });

      List<Map<String, dynamic>> responseTimeData = [];
      responseTimes24h.sort();
      int step = responseTimes24h.length > 20 ? (responseTimes24h.length / 20).ceil() : 1;
      for (int i = 0; i < responseTimes24h.length; i += step) {
        if (i < responseTimes24h.length) {
          responseTimeData.add({
            'index': responseTimeData.length,
            'time': responseTimes24h[i],
          });
        }
      }

      setState(() {
        _tasksCompleted = tasksCompleted;
        _avgResponseTime = responseTimes > 0 ? totalResponseTime / responseTimes : 0;
        _areasCovered = areas.length;
        _userRating = 4.8;
        _hoursWorked = totalHours;

        _tasksByDayData = tasksByDayData;
        _responseTimeData = responseTimeData;
        _wasteTypeData = wasteTypeData;

        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching performance data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Performance'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _fetchPerformanceData();
            },
            itemBuilder: (context) {
              return _timePeriods.map((period) {
                return PopupMenuItem(
                  value: period,
                  child: Row(
                    children: [
                      if (_selectedPeriod == period)
                        const Icon(Icons.check, color: Colors.blue, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(period),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPerformanceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodHeader(),
                    const SizedBox(height: 24),
                    _buildStatCards(),
                    const SizedBox(height: 24),
                    _buildDailyTasksChart(),
                    const SizedBox(height: 24),
                    _buildWasteTypeChart(),
                    const SizedBox(height: 24),
                    _buildResponseTimeChart(),
                    const SizedBox(height: 24),
                    _buildPerformanceInsights(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPeriod,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last updated: ${DateFormat('MMM dd, yyyy - h:mm a').format(DateTime.now())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _fetchPerformanceData,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Tasks Completed',
                _tasksCompleted.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'Response Time',
                '${_avgResponseTime.toStringAsFixed(1)} min',
                Icons.timer,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Areas Covered',
                _areasCovered.toString(),
                Icons.map,
                Colors.purple,
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'Customer Rating',
                '${_userRating.toStringAsFixed(1)}/5',
                Icons.star,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Hours Worked',
          '${_hoursWorked.toStringAsFixed(1)} hrs',
          Icons.access_time_filled,
          Colors.teal,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTasksChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tasks Completed (Last 7 Days)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Total: $_tasksCompleted',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_tasksByDayData.isEmpty
                      ? 5
                      : (_tasksByDayData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b) + 2)).toDouble(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${_tasksByDayData[groupIndex]['day']}: ${rod.toY.round()} tasks',
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
                          if (value < 0 || value >= _tasksByDayData.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _tasksByDayData[value.toInt()]['day'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const Text('0');
                          }
                          if (value % 1 == 0) {
                            return Text(value.toInt().toString());
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: List.generate(_tasksByDayData.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (_tasksByDayData[index]['count'] as int).toDouble(),
                          color: Colors.blue.withOpacity(0.7),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: (_tasksByDayData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                            color: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteTypeChart() {
    if (_wasteTypeData.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Color> pieColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.amber,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    double totalValue = _wasteTypeData.values.fold(0, (sum, value) => sum + value);

    _wasteTypeData.forEach((key, value) {
      final double percentage = (value / totalValue) * 100;
      sections.add(
        PieChartSectionData(
          color: pieColors[colorIndex % pieColors.length],
          value: value,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Waste Types Handled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(_wasteTypeData.length, (index) {
                String key = _wasteTypeData.keys.elementAt(index);
                Color color = pieColors[index % pieColors.length];

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      key,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseTimeChart() {
    if (_responseTimeData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Response Times',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Avg: ${_avgResponseTime.toStringAsFixed(1)} min',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 30 == 0) {
                            return Text('${value.toInt()} min');
                          }
                          return const SizedBox();
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _responseTimeData
                          .map((point) => FlSpot(
                                point['index'].toDouble(),
                                point['time'].toDouble(),
                              ))
                          .toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(
                        show: false,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withOpacity(0.1),
                      ),
                    ),
                  ],
                  minX: 0,
                  maxX: (_responseTimeData.length - 1).toDouble(),
                  minY: 0,
                  maxY: _responseTimeData.isEmpty
                      ? 100
                      : (_responseTimeData.map((e) => e['time'] as double).reduce((a, b) => a > b ? a : b) * 1.2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Response times from recent tasks',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceInsights() {
    List<Map<String, dynamic>> insights = [];

    if (_tasksCompleted > 0) {
      String taskMessage;
      Color taskColor;

      if (_tasksCompleted >= 15) {
        taskMessage = 'Excellent task completion rate! You\'re one of our top performers.';
        taskColor = Colors.green;
      } else if (_tasksCompleted >= 8) {
        taskMessage = 'Good progress on task completion. Keep up the good work!';
        taskColor = Colors.blue;
      } else {
        taskMessage = 'You\'re making progress. Try to increase your task completion rate.';
        taskColor = Colors.orange;
      }

      insights.add({
        'message': taskMessage,
        'icon': Icons.task_alt,
        'color': taskColor,
      });
    }

    if (_avgResponseTime > 0) {
      String responseMessage;
      Color responseColor;

      if (_avgResponseTime < 30) {
        responseMessage = 'Outstanding response time! You respond to tasks very quickly.';
        responseColor = Colors.green;
      } else if (_avgResponseTime < 60) {
        responseMessage = 'Good response time. You respond to tasks promptly.';
        responseColor = Colors.blue;
      } else {
        responseMessage = 'Try to improve your response time by checking for new tasks more frequently.';
        responseColor = Colors.orange;
      }

      insights.add({
        'message': responseMessage,
        'icon': Icons.speed,
        'color': responseColor,
      });
    }

    if (_userRating > 0) {
      String ratingMessage;
      Color ratingColor;

      if (_userRating >= 4.5) {
        ratingMessage = 'Citizens love your work! Keep up the excellent quality.';
        ratingColor = Colors.green;
      } else if (_userRating >= 4.0) {
        ratingMessage = 'Good citizen satisfaction rating. Focus on maintaining quality.';
        ratingColor = Colors.blue;
      } else {
        ratingMessage = 'Work on improving citizen satisfaction with thorough cleanups.';
        ratingColor = Colors.orange;
      }

      insights.add({
        'message': ratingMessage,
        'icon': Icons.thumb_up,
        'color': ratingColor,
      });
    }

    return insights.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...insights.map((insight) => _buildInsightCard(
                    message: insight['message'],
                    icon: insight['icon'],
                    color: insight['color'],
                  )),
            ],
          );
  }

  Widget _buildInsightCard({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}