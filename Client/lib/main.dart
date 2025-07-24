import 'package:flutter/material.dart';
import 'signup.dart';
import 'login.dart';
import 'welcome.dart'; // NEW page


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/',  // Start on WelcomePage
          routes: {
      '/': (context) => const WelcomePage(),
      '/signup': (context) => const SignupPage(),
      '/login': (context) => LoginPage(),
    }

    );
  }
}
