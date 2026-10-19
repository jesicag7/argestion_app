import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. IMPORTANTE: Sumar la librería de Firebase
import 'firebase_options.dart'; // 2. IMPORTANTE: El archivo de credenciales de su proyecto
import 'app_background.dart';
import 'login_screen.dart';

void main() async {
  // 3. Le agregamos 'async' para poder esperar a la base de datos
  // Asegura que los canales nativos del navegador/emulador estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // 4. INICIALIZACIÓN DE FIREBASE
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ArgestionApp());
}

class ArgestionApp extends StatelessWidget {
  const ArgestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARGestión',
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          AppBackground(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          brightness: Brightness.light,
          primary: const Color(0xFF059669),
          secondary: const Color(0xFF10B981),
          tertiary: const Color(0xFF34D399),
          error: const Color(0xFFDC2626),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 5,
          shadowColor: const Color(0x0F0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
          ),
        ),
        dividerColor: const Color(0xFFE2E8F0),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF0F172A),
          displayColor: const Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF059669),
          unselectedItemColor: Color(0xFF64748B),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF059669)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF059669).withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF059669)
                  : const Color(0xFF64748B),
            );
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF64748B)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
          ),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
