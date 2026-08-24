import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'models/usuario_model.dart'; 

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; 
  
  // Variables para controlar la visibilidad de las contraseñas
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cuitController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController(); // ◄ Nuevo controlador
  
  String _categoriaSeleccionada = 'A'; 

  @override
  void dispose() {
    _nombreController.dispose();
    _cuitController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // ◄ Limpieza del nuevo controlador
    super.dispose();
  }

  Future<void> _registrarUsuario() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        String uidUser = userCredential.user!.uid;

        UsuarioModel nuevoUsuario = UsuarioModel(
          uid: uidUser,
          nombre: _nombreController.text.trim(),
          cuit: _cuitController.text.trim(),
          categoria: _categoriaSeleccionada,
          email: _emailController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uidUser)
            .set(nuevoUsuario.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✔️ ¡Usuario registrado con éxito en el sistema!'),
              backgroundColor: Color(0xFF10B981), 
            ),
          );
          Navigator.pop(context); 
        }

      } on FirebaseAuthException catch (e) {
        String mensajeError = 'Ocurrió un error en el registro.';
        if (e.code == 'email-already-in-use') {
          mensajeError = 'Este correo electrónico ya está registrado.';
        } else if (e.code == 'weak-password') {
          mensajeError = 'La contraseña es demasiado débil (mínimo 6 caracteres).';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeError), backgroundColor: const Color(0xFFFF3366)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF3366)),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Modificamos el estilo base para que acepte un botón opcional al final (suffixIcon)
  InputDecoration _inputStyle(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      suffixIcon: suffix, // ◄ Acá se engancha el botón del ojito
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: LinearProgressIndicator(color: Color(0xFF6366F1)),
                  ),

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

                TextFormField(
                  controller: _nombreController,
                  enabled: !_isLoading,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('Nombre Completo', Icons.person_outline),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresá tu nombre' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _cuitController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('CUIT (Solo números)', Icons.badge_outlined),
                  validator: (v) => (v == null || v.length != 11) ? 'El CUIT debe tener exactamente 11 dígitos' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _categoriaSeleccionada,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: _inputStyle('Categoría Monotributo', Icons.bar_chart_rounded),
                  items: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text('Categoría $cat')))
                      .toList(),
                  onChanged: _isLoading ? null : (val) {
                    setState(() {
                      _categoriaSeleccionada = val!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('Correo Electrónico', Icons.email_outlined),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email inválido' : null,
                ),
                const SizedBox(height: 16),

                // 🔑 Campo Contraseña 1 (Con Ojito)
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword, // Vinculado al estado booleano
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle(
                    'Contraseña', 
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 16),

                // 🔑 Campo Confirmar Contraseña 2 (Con Ojito y Validación)
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureConfirmPassword, // Ojito independiente
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle(
                    'Confirmar Contraseña', 
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirmá tu contraseña';
                    if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registrarUsuario,
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

                TextButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.pop(context); 
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
}