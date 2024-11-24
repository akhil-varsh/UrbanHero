import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:guardian/components/citizen/cart.dart';
import 'package:guardian/components/manager/mappage.dart';
import 'package:guardian/components/manager/worker_management.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guardian/components/citizen/profilec.dart';
import 'package:guardian/components/citizen/track_your_issues.dart';
import 'package:guardian/components/worker/detection.dart';
import 'package:guardian/components/worker/worker_stats.dart';
import 'package:guardian/components/citizen/throwable.dart';
import 'package:guardian/screens/flutter-login.dart';
import 'components/citizen/home_screen.dart';
import 'components/manager/manager_home.dart';
import 'components/manager/profilem.dart';
import 'components/worker/profilew.dart';
import 'components/worker/worker_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        return  WorkerHomeScreen(); // Worker Dashboard
      case 'manager':
        return  ManagerPage(); // Manager Dashboard
      default:
        return  LoginScreen(); // Redirect to login if no session
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GG',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<Widget>(
        future: _determineHomeScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading app"));
          }
          return snapshot.data ??  LoginScreen();
        },
      ),
      routes: {

        '/Loginpage': (context) =>  LoginScreen(),
        '/profilew': (context) =>  Profilew(),
        '/profilem': (context) =>  ProfileManager(),
        '/profilec': (context) =>  Profilec(),
        '/map': (context) => MapPage(),
        '/throw': (context) =>  PolyGeofence(),
        '/res': (context) =>  PolyGeofenceServic(),
        '/citizen-dashboard': (context) =>  SecondPage(),
        '/perform': (context) =>  WorkerStatsScreen(),
        '/worker-dashboard': (context) =>  WorkerHomeScreen(),
        '/manager-dashboard': (context) =>  ManagerPage(),
        '/trackissues': (context) =>  TrackIssuesPage(),
        '/cart': (context) => Cart(),
        '/assign': (context) => WorkerManagement(),
      },
    );
  }
}
