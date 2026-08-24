import 'package:flutter/material.dart';
import 'main_navigation.dart'; 
import 'registro_screen.dart'; // ◄ Importamos la nueva pantalla de registro

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌌 Cambiamos el fondo blanco por el modo oscuro profundo
      backgroundColor: const Color(0xFF0F172A), 
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ARGestión',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 40),
              
              // Contenedor del icono con estética de cristal oscuro
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155), width: 2),
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded, // Icono un poco más moderno para escaneo
                  size: 100, 
                  color: Color(0xFF6366F1), // Índigo eléctrico unificado
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Acceso Seguro Biométrico',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para tu seguridad, esta aplicación utiliza datos biométricos para verificar tu identidad y acceder a tus datos de ARCA.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.4),
              ),
              const SizedBox(height: 40),
              
              // Botón de Escaneo Facial con Degradado Moderno
              Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MainNavigation()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Iniciar Escaneo Facial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Alternativa Clave Fiscal estilizada
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Alternativa: Usar Clave Fiscal',
                  style: TextStyle(color: Color(0xFF64748B), decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 24),
              
              // 🆕 ¡BOTÓN DE ACCESO AL REGISTRO DE USUARIO NUEVO!
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿No tenés cuenta?',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  TextButton(
                    onPressed: () {
                      // 🚀 Salta de forma limpia a la pantalla de Registro
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegistroScreen()),
                      );
                    },
                    child: const Text(
                      'Registrate acá',
                      style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}