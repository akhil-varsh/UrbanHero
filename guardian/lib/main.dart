import 'package:flutter/material.dart';
import 'package:guardian/components/citizen/profile.dart';

import 'package:guardian/screens/flutter-login.dart';

import 'components/citizen/home_screen.dart';
import 'components/manager/manager_page.dart';
import 'components/worker/profile.dart';
import 'components/worker/worker_home.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GG',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(),
      routes: {
        '/Loginpage': (context) => LoginPage(),
        '/profile': (context) => Profilew(),
        '/Profile': (context) => Profile(),
        '/citizen-dashboard': (context) => SecondPage(),
        '/worker-dashboard': (context) => WorkerHomeScreen(),
        '/manager-dashboard': (context) => ManagerPage(),
      },

    );

  }

}