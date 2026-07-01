import 'package:flutter/material.dart';
import 'main_navigation.dart'; 

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ARGestión',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF0052CC)),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD0E0FF), width: 2),
                ),
                child: const Icon(
                  Icons.face, 
                  size: 100, 
                  color: Color(0xFF0052CC),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Acceso Seguro con Reconocimiento Facial',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para tu seguridad, esta aplicación utiliza datos biométricos para verificar tu identidad y acceder a tus datos de ARCA.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, 
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MainNavigation()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052CC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Iniciar Escaneo Facial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Alternativa: Usar Clave Fiscal',
                  style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}