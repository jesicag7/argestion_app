class UsuarioModel {
  final String uid;
  final String nombre;
  final String cuit;
  final String categoria;
  final String email;

  UsuarioModel({
    required this.uid,
    required this.nombre,
    required this.cuit,
    required this.categoria,
    required this.email,
  });

  // Convierte el objeto a un mapa JSON para subirlo a Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'cuit': cuit,
      'categoria': categoria,
      'email': email,
    };
  }
}