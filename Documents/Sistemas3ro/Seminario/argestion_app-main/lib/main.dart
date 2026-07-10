import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. IMPORTANTE: Sumar la librería de Firebase
import 'firebase_options.dart'; // 2. IMPORTANTE: El archivo de credenciales de su proyecto
import 'login_screen.dart'; 

void main() async { // 3. Le agregamos 'async' para poder esperar a la base de datos
  // Asegura que los canales nativos del navegador/emulador estén listos
  WidgetsFlutterBinding.ensureInitialized();
  
  // 4. INICIALIZACIÓN DE FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), 
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFFFF3366), 
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A), 
        useMaterial3: true,
      ),
      home: const LoginScreen(), 
    );
  }
}