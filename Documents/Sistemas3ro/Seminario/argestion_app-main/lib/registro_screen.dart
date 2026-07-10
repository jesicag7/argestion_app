import 'package:flutter/material.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para capturar lo que escribe el usuario
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cuitController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  String _categoriaSeleccionada = 'A'; // Categoría por defecto

  @override
  void dispose() {
    _nombreController.dispose();
    _cuitController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _registrarUsuario() {
    if (_formKey.currentState!.validate()) {
      // Acá va a ir la conexión a Firebase Auth y Firestore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registrando a ${_nombreController.text} en el sistema...'),
          backgroundColor: const Color(0xFF6366F1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo oscuro profundo
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono e Identidad
                const Icon(Icons.person_add_alt_1_rounded, size: 60, color: Color(0xFF6366F1)),
                const SizedBox(height: 16),
                const Text(
                  'Crear Cuenta Nueva',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresá tus datos para darte de alta en ARGestión',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Campo Nombre
                TextFormField(
                  controller: _nombreController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('Nombre Completo', Icons.person_outline),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresá tu nombre' : null,
                ),
                const SizedBox(height: 16),

                // Campo CUIT
                TextFormField(
                  controller: _cuitController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('CUIT (Solo números)', Icons.badge_outlined),
                  validator: (v) => (v == null || v.length < 11) ? 'CUIT inválido (11 dígitos)' : null,
                ),
                const SizedBox(height: 16),

                // Selector de Categoría Monotributo (Dropdown)
                DropdownButtonFormField<String>(
                  value: _categoriaSeleccionada,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: _inputStyle('Categoría Monotributo', Icons.bar_chart_rounded),
                  items: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text('Categoría $cat')))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _categoriaSeleccionada = val!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Campo Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('Correo Electrónico', Icons.email_outlined),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email inválido' : null,
                ),
                const SizedBox(height: 16),

                // Campo Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('Contraseña', Icons.lock_outline),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 32),

                // Botón Registrase con Degradado Moderno
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _registrarUsuario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Registrarme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),

                // Link para volver al Login si ya tiene cuenta
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Vuelve a la pantalla anterior (Login)
                  },
                  child: const Text(
                    '¿Ya tenés cuenta? Iniciá sesión',
                    style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF475569)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFF3366)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFF3366), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}