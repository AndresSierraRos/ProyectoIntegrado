import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pantalla de registro de nuevos usuarios.
/// Permite al usuario introducir nombre, correo y contraseña,
/// crea la cuenta con Firebase Auth y la guarda en Firestore.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para los campos de texto
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  /// Método que se encarga de registrar al usuario:
  /// 1. Crea la cuenta en Firebase Auth.
  /// 2. Guarda los datos iniciales en la colección "usuarios" de Firestore.
  /// 3. Cierra sesión y muestra un diálogo informando que está pendiente de aprobación.
  /// 4. Maneja errores específicos de FirebaseAuthException para mostrar mensajes amigables.
  Future<void> register() async {
    try {
      // 1. Crear cuenta en Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2. Guardar datos en Firestore bajo "usuarios/{uid}"
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(userCredential.user!.uid)
          .set({
        "uid": userCredential.user!.uid,
        "nombre": nameController.text.trim(),
        "email": emailController.text.trim(),
        "fechaRegistro": Timestamp.now(),
        'descripcion': '',
        'fotoPerfilBase64': null,
        'rango': 'usuario',
        "estado": "pendiente", 
      });

      // 3. Cerrar la sesión recién creada y notificar al usuario
      await FirebaseAuth.instance.signOut();
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Registro pendiente"),
          content: const Text(
              "Tu cuenta ha sido creada y está pendiente de aprobación por un administrador."),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Aceptar"),
            ),
          ],
        ),
      );
      // Volver a la pantalla de login
      Navigator.pop(context);

    }
    // Capturar errores específicos de Firebase Auth
    on FirebaseAuthException catch (e) {
      String mensaje;
      switch (e.code) {
        case 'invalid-email':
          mensaje = 'El correo está mal formado.';
          break;
        case 'email-already-in-use':
          mensaje = 'Este correo ya está registrado.';
          break;
        case 'weak-password':
          mensaje = 'La contraseña debe tener al menos 6 caracteres.';
          break;
        case 'operation-not-allowed':
          mensaje = 'El registro con correo y contraseña no está habilitado.';
          break;
        case 'network-request-failed':
          mensaje =
              'Error de red. Por favor, revisa tu conexión e inténtalo de nuevo.';
          break;
        default:
          mensaje = 'Error al registrar: ${e.message}';
      }
      // Mostrar diálogo con el mensaje de error
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error de registro"),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
    // Cualquier otro error no previsto
    catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error inesperado"),
          content: Text("Ocurrió un error: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registro"),
        automaticallyImplyLeading: false, // Sin botón de volver
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        // Columna centrada con los campos de input y el botón
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Campo para el nombre
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            // Campo para el correo
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Correo"),
            ),
            // Campo para la contraseña
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Contraseña"),
              obscureText: true, // Oculta el texto ingresado
            ),
            const SizedBox(height: 24),
            // Botón de registro
            ElevatedButton(
              onPressed: register,
              child: const Text("Registrarse"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}