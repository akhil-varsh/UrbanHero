import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerSettingsPage extends StatefulWidget {
  const ManagerSettingsPage({super.key});

  @override
  State<ManagerSettingsPage> createState() => _ManagerSettingsPageState();
}

class _ManagerSettingsPageState extends State<ManagerSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Settings states
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _autoAssignTasks = false;
  bool _darkMode = false;
  String _selectedLanguage = 'English';
  int _maxTasksPerWorker = 5;
  int _taskTimeout = 24; // hours
  
  final List<String> _languages = ['English', 'Hindi', 'Marathi', 'Telugu', 'Tamil'];
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _autoAssignTasks = prefs.getBool('auto_assign_tasks') ?? false;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _maxTasksPerWorker = prefs.getInt('max_tasks_per_worker') ?? 5;
      _taskTimeout = prefs.getInt('task_timeout') ?? 24;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', _pushNotifications);
    await prefs.setBool('email_notifications', _emailNotifications);
    await prefs.setBool('auto_assign_tasks', _autoAssignTasks);
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('language', _selectedLanguage);
    await prefs.setInt('max_tasks_per_worker', _maxTasksPerWorker);
    await prefs.setInt('task_timeout', _taskTimeout);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showDeleteDataDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Delete Data'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete all completed waste reports? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCompletedReports();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCompletedReports() async {
    try {
      final batch = _firestore.batch();
      final completedReports = await _firestore
          .collection('waste_reports')
          .where('status', isEqualTo: 'completed')
          .get();
      
      for (var doc in completedReports.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completed reports deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    try {
      // In a real app, you would implement CSV export functionality here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data export functionality coming soon!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      _pushNotifications = true;
      _emailNotifications = true;
      _autoAssignTasks = false;
      _darkMode = false;
      _selectedLanguage = 'English';
      _maxTasksPerWorker = 5;
      _taskTimeout = 24;
    });
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Notifications Section
            _buildSettingsSection(
              'Notifications',
              Icons.notifications,
              [
                _buildSwitchTile(
                  'Push Notifications',
                  'Receive push notifications for new reports',
                  _pushNotifications,
                  (value) => setState(() => _pushNotifications = value),
                ),
                _buildSwitchTile(
                  'Email Notifications',
                  'Receive email updates for important events',
                  _emailNotifications,
                  (value) => setState(() => _emailNotifications = value),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Task Management Section
            _buildSettingsSection(
              'Task Management',
              Icons.assignment,
              [
                _buildSwitchTile(
                  'Auto-assign Tasks',
                  'Automatically assign tasks to available workers',
                  _autoAssignTasks,
                  (value) => setState(() => _autoAssignTasks = value),
                ),
                _buildSliderTile(
                  'Max Tasks per Worker',
                  'Maximum number of tasks assigned to one worker',
                  _maxTasksPerWorker.toDouble(),
                  1,
                  10,
                  (value) => setState(() => _maxTasksPerWorker = value.round()),
                ),
                _buildSliderTile(
                  'Task Timeout (hours)',
                  'Hours before a task is marked as overdue',
                  _taskTimeout.toDouble(),
                  1,
                  72,
                  (value) => setState(() => _taskTimeout = value.round()),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // App Preferences Section
            _buildSettingsSection(
              'App Preferences',
              Icons.settings,
              [
                _buildSwitchTile(
                  'Dark Mode',
                  'Use dark theme for the app',
                  _darkMode,
                  (value) => setState(() => _darkMode = value),
                ),
                _buildDropdownTile(
                  'Language',
                  'Select app language',
                  _selectedLanguage,
                  _languages,
                  (value) => setState(() => _selectedLanguage = value!),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Data Management Section
            _buildSettingsSection(
              'Data Management',
              Icons.storage,
              [
                _buildActionTile(
                  'Export Data',
                  'Export waste reports to CSV',
                  Icons.download,
                  Colors.blue,
                  _exportData,
                ),
                _buildActionTile(
                  'Delete Completed Reports',
                  'Remove all completed waste reports',
                  Icons.delete,
                  Colors.red,
                  _showDeleteDataDialog,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // System Section
            _buildSettingsSection(
              'System',
              Icons.build,
              [
                _buildActionTile(
                  'Reset to Defaults',
                  'Reset all settings to default values',
                  Icons.refresh,
                  Colors.orange,
                  _resetToDefaults,
                ),
                _buildInfoTile('App Version', '1.0.0'),
                _buildInfoTile('Build Number', '1'),
              ],
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, IconData icon, List<Widget> children) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green.shade700,
      ),
    );
  }

  Widget _buildSliderTile(String title, String subtitle, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(min.round().toString()),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: (max - min).round(),
                  label: value.round().toString(),
                  onChanged: onChanged,
                  activeColor: Colors.green.shade700,
                ),
              ),
              Text(max.round().toString()),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value.round().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(String title, String subtitle, String value, List<String> options, ValueChanged<String?> onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: DropdownButton<String>(
        value: value,
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: onChanged,
        underline: Container(),
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Text(
        value,
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
