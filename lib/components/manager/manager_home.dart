import 'package:UrbanHero/components/manager/orders_page.dart';
import 'package:UrbanHero/components/manager/profilem.dart';
import 'package:UrbanHero/components/manager/statistics.dart';
import 'package:UrbanHero/components/manager/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:UrbanHero/components/manager/reported_issues.dart';
import 'package:UrbanHero/components/manager/worker_management.dart';
import 'package:UrbanHero/components/manager/worker_reports.dart'; // Added import for worker reports
import 'package:fl_chart/fl_chart.dart' as fl;
import 'mappage.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key});

  @override
  _ManagerPageState createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;
  int _selectedChartType = 0; // 0 for pie chart, 1 for status bar chart, 2 for waste type bar chart

  @override
  void initState() {
    super.initState();
    // Removed _fetchWeeklyReportData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
            'Manager Dashboard',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            )
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Removed _fetchWeeklyReportData();
              // Refresh logic for other data if needed, or simply trigger a rebuild of streams
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // Notification logic here
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade700, // Adjusted gradient to match mappage if needed or keep as is
              const Color(0xFFF5F7FA),
            ],
            stops: const [0.0, 0.3], // Adjust stop if needed
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCardsStream(), // Changed to StreamBuilder version
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTaskChartStream(), // Changed to StreamBuilder version
                        const SizedBox(height: 24),
                        _buildQuickActions(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Status cards for quick metrics - StreamBuilder version
  Widget _buildStatusCardsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('waste_reports').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              Expanded(child: _buildStatusCard("Total Reports", "...", Icons.assignment, Colors.blue.shade700)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatusCard("Pending", "...", Icons.pending_actions, Colors.orange.shade700)),
            ],
          );
        }
        if (snapshot.hasError) {
          print('Error loading status cards: ${snapshot.error}');
          return const Center(child: Text("Error loading status"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Row(
            children: [
              Expanded(child: _buildStatusCard("Total Reports", "0", Icons.assignment, Colors.blue.shade700)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatusCard("Pending", "0", Icons.pending_actions, Colors.orange.shade700)),
            ],
          );
        }

        int totalReports = snapshot.data!.docs.length;
        int pendingReports = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String status = data['status']?.toLowerCase() ?? 'not assigned';
          bool isWorkerAssigned = data.containsKey('assignedWorker') && 
                                data['assignedWorker'] != null && 
                                (data['assignedWorker'] as String? ?? '').isNotEmpty;
          
          // Considered pending if explicitly 'not assigned', or no worker is assigned yet.
          // Or if assigned, but status is neither 'completed', 'in progress', nor 'started'.
          if (status == 'not assigned' || !isWorkerAssigned) return true;
          if (isWorkerAssigned && status != 'completed' && status != 'in progress' && status != 'started') return true;
          return false;
        }).length;

        return Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                "Total Reports",
                totalReports.toString(),
                Icons.assignment,
                Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                "Pending",
                pendingReports.toString(),
                Icons.pending_actions,
                Colors.orange.shade700,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Sidebar Navigation (Drawer)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade700,
                    Colors.green.shade500,
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: AssetImage('assets/images/google.png'),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'manager@gmail.com',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _drawerItem(Icons.dashboard, 'Dashboard', () {
              Navigator.pop(context);
            }),
            _drawerItem(Icons.list_alt, 'Reported Issues', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportedIssues()));
            }),
            _drawerItem(Icons.map_outlined, 'Map View', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPage()));
            }),
            _drawerItem(Icons.group, 'Worker Management', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkerManagement()));
            }),
            _drawerItem(Icons.assignment_outlined, 'Worker Reports', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkerReports()));
            }),
            _drawerItem(Icons.inventory_2, 'Incentive Orders', () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerOrdersPage()));

              // Add settings navigation
            }),
            const Divider(),
            _drawerItem(Icons.person, 'Profile', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileManager()));
            }),
            _drawerItem(Icons.settings, 'Settings', () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerSettingsPage()));

              // Add settings navigation
            }),
            _drawerItem(Icons.logout, 'Logout', () {
              // Add logout functionality
            }),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade700),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  // 🔹 Interactive Chart Section - StreamBuilder version
  Widget _buildTaskChartStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('waste_reports').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Error loading task chart: ${snapshot.error}');
          return const Center(child: Text("Error loading chart data"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(child: Text("No reports available to display in chart.")),
          );
        }

        int pieAssignedCount = 0;
        int pieUnassignedCount = 0;

        Map<String, int> statusCountsBar = {
          'Not Assigned': 0,
          'Assigned': 0,
          'In Progress': 0,
          'Completed': 0,
        };

        Map<String, int> wasteTypeCounts = {};

        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String status = data['status']?.toLowerCase() ?? 'not assigned';
          bool isWorkerAssigned = data.containsKey('assignedWorker') && 
                                data['assignedWorker'] != null && 
                                (data['assignedWorker'] as String? ?? '').isNotEmpty;
          String wasteType = data['wasteType'] as String? ?? 'Other';

          // Pie Chart Logic
          if (isWorkerAssigned) {
            pieAssignedCount++;
          } else {
            pieUnassignedCount++;
          }

          // Bar Chart Logic (Detailed Status)
          if (status == 'completed') {
            statusCountsBar['Completed'] = (statusCountsBar['Completed'] ?? 0) + 1;
          } else if (status == 'in progress' || status == 'started') {
            statusCountsBar['In Progress'] = (statusCountsBar['In Progress'] ?? 0) + 1;
          } else if (isWorkerAssigned) { 
            statusCountsBar['Assigned'] = (statusCountsBar['Assigned'] ?? 0) + 1;
          } else { 
            statusCountsBar['Not Assigned'] = (statusCountsBar['Not Assigned'] ?? 0) + 1;
          }

          // Waste Type Bar Chart Logic
          wasteTypeCounts[wasteType] = (wasteTypeCounts[wasteType] ?? 0) + 1;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Task Distribution",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      _buildChartTypeButton(0, Icons.pie_chart),
                      const SizedBox(width: 8),
                      _buildChartTypeButton(1, Icons.bar_chart),
                      const SizedBox(width: 8),
                      _buildChartTypeButton(2, Icons.category), // Changed icon
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: _selectedChartType == 0
                    ? _buildPieChart(pieAssignedCount, pieUnassignedCount)
                    : _selectedChartType == 1
                    ? _buildBarChartRealtime(statusCountsBar)
                    : _buildWasteTypeBarChart(wasteTypeCounts), // New chart
              ),
              const SizedBox(height: 16),
              if (_selectedChartType == 0)
                _buildPieChartLegend(pieAssignedCount, pieUnassignedCount),
              if (_selectedChartType == 1)
                _buildBarChartLegendRealtime(statusCountsBar),
              if (_selectedChartType == 2)
                _buildWasteTypeLegend(wasteTypeCounts), // New legend
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartTypeButton(int index, IconData icon) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChartType = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _selectedChartType == index
              ? Colors.green.shade100
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: _selectedChartType == index
              ? Colors.green.shade700
              : Colors.grey.shade600,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildPieChart(int assignedCount, int unassignedCount) {
    double total = (assignedCount + unassignedCount).toDouble();
    if (total == 0) {
        return const Center(child: Text("No data for Pie Chart"));
    }
    double assignedPercentage = total > 0 ? (assignedCount / total * 100) : 0;
    double unassignedPercentage = total > 0 ? (unassignedCount / total * 100) : 0;

    return fl.PieChart(
      fl.PieChartData(
        sections: [
          fl.PieChartSectionData(
            color: Colors.green.shade500,
            value: assignedCount.toDouble(),
            title: '${assignedPercentage.toStringAsFixed(1)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          fl.PieChartSectionData(
            color: Colors.redAccent,
            value: unassignedCount.toDouble(),
            title: '${unassignedPercentage.toStringAsFixed(1)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        centerSpaceColor: Colors.white,
      ),
    );
  }

  Widget _buildPieChartLegend(int assigned, int unassigned) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          'Assigned', 
          '$assigned Tasks',
          Colors.green.shade500,
        ),
        const SizedBox(width: 24),
        _buildLegendItem(
          'Unassigned',
          '$unassigned Tasks',
          Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildBarChartRealtime(Map<String, int> statusCounts) {
    final List<fl.BarChartGroupData> barGroups = [];
    int x = 0;
    statusCounts.forEach((status, count) {
      barGroups.add(
        fl.BarChartGroupData(
          x: x++,
          barRods: [
            fl.BarChartRodData(
              toY: count.toDouble(),
              color: _getColorForStatus(status),
              width: 22,
              borderRadius: BorderRadius.circular(4)
            )
          ],
        )
      );
    });

    // Determine maxY
    double maxY = 0;
    if (statusCounts.values.isNotEmpty) {
      maxY = statusCounts.values.map((e) => e.toDouble()).reduce((a, b) => a > b ? a : b);
    }
    maxY = (maxY == 0) ? 10 : (maxY * 1.2); // Add some padding, default to 10 if all are 0


    return fl.BarChart(
      fl.BarChartData(
        alignment: fl.BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: fl.BarTouchData(
          enabled: true,
          touchTooltipData: fl.BarTouchTooltipData(
            tooltipBgColor: Colors.grey.shade100,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String status = statusCounts.keys.elementAt(group.x.toInt());
              return fl.BarTooltipItem(
                '$status\n',
                const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: (rod.toY - rod.fromY).round().toString(),
                    style: TextStyle(
                      color: _getColorForStatus(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }
          ),
        ),
        titlesData: fl.FlTitlesData(
          show: true,
          bottomTitles: fl.AxisTitles(
            sideTitles: fl.SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final titles = statusCounts.keys.toList();
                if (value.toInt() >= 0 && value.toInt() < titles.length) {
                  final String text = titles[value.toInt()].replaceAll(' ', '\n');
                  return fl.SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(text, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
                  );
                }
                return const Text('');
              },
              reservedSize: 38,
            ),
          ),
          leftTitles: fl.AxisTitles(
            sideTitles: fl.SideTitles(showTitles: true, reservedSize: 32, interval: maxY / 5 > 1 ? (maxY / 5).floorToDouble().clamp(1,double.infinity) : 1),
          ),
          rightTitles: const fl.AxisTitles(sideTitles: fl.SideTitles(showTitles: false)),
          topTitles: const fl.AxisTitles(sideTitles: fl.SideTitles(showTitles: false)),
        ),
        gridData: fl.FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: maxY / 5 > 1 ? (maxY / 5).floorToDouble().clamp(1,double.infinity) : 1,
        ),
        borderData: fl.FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildBarChartLegendRealtime(Map<String, int> statusCounts) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Wrap( // Use Wrap for better responsiveness
        alignment: WrapAlignment.center,
        spacing: 16.0, // Horizontal spacing
        runSpacing: 8.0, // Vertical spacing if items wrap
        children: [
          _buildLegendItem('Not Assigned', '${statusCounts['Not Assigned'] ?? 0}', _getColorForStatus('Not Assigned')),
          _buildLegendItem('Assigned', '${statusCounts['Assigned'] ?? 0}', _getColorForStatus('Assigned')),
          _buildLegendItem('In Progress', '${statusCounts['In Progress'] ?? 0}', _getColorForStatus('In Progress')),
          _buildLegendItem('Completed', '${statusCounts['Completed'] ?? 0}', _getColorForStatus('Completed')),
        ],
      ),
    );
  }

  // New: Waste Type Bar Chart
  Widget _buildWasteTypeBarChart(Map<String, int> wasteTypeCounts) {
    final List<fl.BarChartGroupData> barGroups = [];
    int x = 0;
    
    // Define a list of common waste types for consistent ordering and color mapping
    final wasteTypesOrder = ['Organic', 'Plastic', 'Paper', 'Metal', 'Glass', 'E-waste', 'Other'];
    Map<String, int> orderedWasteTypeCounts = {};

    for (String type in wasteTypesOrder) {
        orderedWasteTypeCounts[type] = wasteTypeCounts[type] ?? 0;
    }
    // Add any other types not in the predefined list to 'Other' or handle them separately
    wasteTypeCounts.forEach((key, value) {
        if (!wasteTypesOrder.contains(key)) {
            orderedWasteTypeCounts['Other'] = (orderedWasteTypeCounts['Other'] ?? 0) + value;
        }
    });


    orderedWasteTypeCounts.forEach((type, count) {
      if (count > 0 || wasteTypesOrder.contains(type)) { // Ensure all predefined types are shown, even if count is 0 for a cleaner look
        barGroups.add(
          fl.BarChartGroupData(
            x: x++,
            barRods: [
              fl.BarChartRodData(
                toY: count.toDouble(),
                color: _getColorForWasteType(type),
                width: 22,
                borderRadius: BorderRadius.circular(4)
              )
            ],
          )
        );
      }
    });
    
    if (barGroups.isEmpty) {
        return const Center(child: Text("No waste type data available."));
    }

    double maxY = 0;
    if (orderedWasteTypeCounts.values.isNotEmpty) {
      maxY = orderedWasteTypeCounts.values.map((e) => e.toDouble()).reduce((a, b) => a > b ? a : b);
    }
    maxY = (maxY == 0) ? 10 : (maxY * 1.2);

    return fl.BarChart(
      fl.BarChartData(
        alignment: fl.BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: fl.BarTouchData(
          enabled: true,
          touchTooltipData: fl.BarTouchTooltipData(
            tooltipBgColor: Colors.grey.shade100,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String type = orderedWasteTypeCounts.keys.elementAt(group.x.toInt());
              return fl.BarTooltipItem(
                '$type\n',
                const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: rod.toY.round().toString(),
                    style: TextStyle(
                      color: _getColorForWasteType(type),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }
          ),
        ),
        titlesData: fl.FlTitlesData(
          show: true,
          bottomTitles: fl.AxisTitles(
            sideTitles: fl.SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final titles = orderedWasteTypeCounts.keys.toList();
                if (value.toInt() >= 0 && value.toInt() < titles.length) {
                  return fl.SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4.0,
                    child: Text(titles[value.toInt()].substring(0,3), style: const TextStyle(fontSize: 10)), // Abbreviate for space
                  );
                }
                return const Text('');
              },
              reservedSize: 38,
            ),
          ),
          leftTitles: fl.AxisTitles(
            sideTitles: fl.SideTitles(showTitles: true, reservedSize: 32, interval: maxY / 5 > 1 ? (maxY / 5).floorToDouble().clamp(1,double.infinity) : 1),
          ),
          rightTitles: const fl.AxisTitles(sideTitles: fl.SideTitles(showTitles: false)),
          topTitles: const fl.AxisTitles(sideTitles: fl.SideTitles(showTitles: false)),
        ),
        gridData: fl.FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: maxY / 5 > 1 ? (maxY / 5).floorToDouble().clamp(1,double.infinity) : 1,
        ),
        borderData: fl.FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  // New: Waste Type Legend
  Widget _buildWasteTypeLegend(Map<String, int> wasteTypeCounts) {
    final wasteTypesOrder = ['Organic', 'Plastic', 'Paper', 'Metal', 'Garbage', 'E-waste', 'Other'];
    Map<String, int> orderedWasteTypeCounts = {};
     for (String type in wasteTypesOrder) {
        orderedWasteTypeCounts[type] = wasteTypeCounts[type] ?? 0;
    }
    wasteTypeCounts.forEach((key, value) {
        if (!wasteTypesOrder.contains(key)) {
            orderedWasteTypeCounts['Other'] = (orderedWasteTypeCounts['Other'] ?? 0) + value;
        }
    });


    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16.0,
        runSpacing: 8.0,
        children: orderedWasteTypeCounts.entries.where((entry) => entry.value > 0 || wasteTypesOrder.contains(entry.key)).map((entry) {
          return _buildLegendItem(entry.key, '${entry.value}', _getColorForWasteType(entry.key));
        }).toList(),
      ),
    );
  }

  Color _getColorForWasteType(String wasteType) {
    switch (wasteType.toLowerCase()) {
      case 'organic':
        return Colors.brown.shade400;
      case 'plastic':
        return Colors.blue.shade400;
      case 'paper':
        return Colors.yellow.shade700;
      case 'metal':
        return Colors.grey.shade600;
      case 'garbage':
        return Colors.cyan.shade300;
      case 'e-waste':
        return Colors.purple.shade400;
      case 'other':
      default:
        return Colors.teal.shade300;
    }
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'not assigned':
        return Colors.redAccent;
      case 'assigned':
        return Colors.orange.shade700;
      case 'in progress':
      case 'started':
        return Colors.blue.shade500;
      case 'completed':
        return Colors.green.shade500;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLegendItem(String title, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🔹 Quick Actions Section - Fixed for no overflow
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
            builder: (context, constraints) {
              // Calculate available width to prevent overflow
              final itemWidth = (constraints.maxWidth - 16) / 2; // 16 is the gap
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                 _actionCard(
                    Icons.assignment_outlined,
                    "Worker Reports",
                    "Daily worker activity",
                    Colors.blue.shade700,
                    () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkerReports()));
                    },
                    width: itemWidth,
                  ),
                  _actionCard(
                    Icons.map,
                    "Monitor Map",
                    "View location data",
                    Colors.orange.shade700,
                        () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPage()));
                    },
                    width: itemWidth,
                  ),
                  _actionCard(
                    Icons.group,
                    "Manage Workers",
                    "Assign and track workers",
                    Colors.green.shade700,
                        () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkerManagement()));
                    },
                    width: itemWidth,
                  ),
                  _actionCard(
                    Icons.analytics,
                    "Analytics",
                    "View detailed reports",
                    Colors.purple.shade700,
                        () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const WasteReportDashboard()));
                    },
                    width: itemWidth,
                  ),
                  
                ],
              );
            }
        ),
      ],
    );
  }

  Widget _actionCard(
      IconData icon,
      String title,
      String subtitle,
      Color color,
      VoidCallback onTap, {
        required double width,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Handle navigation based on index
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportedIssues()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPage()));
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileManager()));
          }
        },
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Issues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Helper function to get day key might be needed if you aggregate data by day for line/bar charts
// String _getDayKeyFromTimestamp(Timestamp timestamp) {
//   DateTime date = timestamp.toDate();
//   // Example: return DateFormat('E').format(date); // Mon, Tue, etc.
//   // Or handle more complex logic for weekly aggregation
//   return DateFormat('yyyy-MM-dd').format(date); // For daily aggregation
// }