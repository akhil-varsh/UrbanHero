import 'package:UrbanHero/components/citizen/standings.dart';
import 'package:UrbanHero/screens/flutter-login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/citizen/cart.dart';
import 'components/citizen/home_screen.dart';
import 'components/citizen/profilec.dart';
import 'components/citizen/throwable.dart';
import 'components/citizen/track_your_issues.dart';
import 'components/citizen/my_reports_page.dart';
import 'components/citizen/community_reports_page.dart';
import 'components/manager/manager_home.dart';
import 'components/manager/mappage.dart';
import 'components/manager/profilem.dart';
import 'components/manager/worker_management.dart';
import 'components/worker/detection.dart';
import 'components/worker/profilew.dart';
import 'components/worker/worker_home.dart';
import 'components/worker/worker_stats.dart';
import 'components/worker/task_details.dart';
import 'components/worker/worker_map.dart';
import 'components/worker/worker_history.dart';
import 'components/worker/worker_daily_report.dart';
import 'components/worker/worker_help.dart';
import 'components/worker/tasks/assigned_tasks_page.dart';
import 'components/worker/tasks/in_progress_tasks_page.dart';
import 'components/worker/tasks/completed_tasks_page.dart';
import 'firebase_options.dart';
import 'screens/manager/manager_orders_page.dart'; // Added import
import 'package:UrbanHero/screens/chatbot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _determineHomeScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('userRole') ?? 'guest'; // Default role

    switch (userRole) {
      case 'citizen':
        return const SecondPage(); // Citizen Dashboard
      case 'worker':
        return const WorkerHomeScreen(); // Worker Dashboard
      case 'manager':
        return const ManagerPage(); // Manager Dashboard
      default:
        return const LoginScreen(); // Redirect to login if no session
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UrbanHero',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _determineHomeScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading app"));
          }
          return snapshot.data ?? const LoginScreen();
        },
      ),
      routes: {
        // Authentication
        '/Loginpage': (context) => const LoginScreen(),
        
        // Profile screens
        '/profilew': (context) => const Profilew(),
        '/profilem': (context) => const ProfileManager(),
        '/profilec': (context) => const Profilec(),
        
        // Manager screens
        '/map': (context) => const MapPage(),
        '/manager-dashboard': (context) => const ManagerPage(),
        '/assign': (context) => const WorkerManagement(),
        '/manager-orders': (context) => const ManagerOrdersPage(), // Added route
          // Worker screens
        '/worker-dashboard': (context) => const WorkerHomeScreen(),
        '/perform': (context) => const WorkerStatsScreen(),
        '/task_details': (context) => const TaskDetailsScreen(),
        '/worker_map': (context) => const WorkerMapScreen(),
        '/worker_history': (context) => const WorkerHistoryScreen(),
        '/worker_daily_report': (context) => const WorkerDailyReportScreen(),
        '/worker_help': (context) => const WorkerHelpScreen(),
        '/assigned_tasks': (context) => const AssignedTasksPage(),
        '/in_progress_tasks': (context) => const InProgressTasksPage(),
        '/completed_tasks': (context) => const CompletedTasksPage(),
          // Citizen screens
        '/throw': (context) => const PolyGeofence(),
        '/res': (context) => const PolyGeofenceServic(),
        '/citizen-dashboard': (context) => const SecondPage(),
        // '/trackissues': (context) => TrackIssuesPage(),
        '/cart': (context) => const Cart(),
        '/Standings': (context) => const Standings(),
        '/my-reports': (context) => const MyReportsPage(),
        '/community-reports': (context) =>  TrackIssuesPage(),
        '/chatbot': (context) => const ChatbotScreen(),
      },
    );
  }
}
