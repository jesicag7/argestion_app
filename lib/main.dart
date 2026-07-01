import 'package:flutter/material.dart';
import 'login_screen.dart'; 

void main() {
  runApp(const ArgestionApp());
}

class ArgestionApp extends StatelessWidget {
  const ArgestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARGestión',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0052CC)),
        useMaterial3: true,
      ),
      home: const LoginScreen(), 
    );
  }
}