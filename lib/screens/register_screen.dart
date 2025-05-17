import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> register() async {
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Guardar en Firestore
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

      // Cerrar sesión y notificar
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
      Navigator.pop(context); // Volver al login

    } on FirebaseAuthException catch (e) {
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
      // Mostrar diálogo de error
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
    } catch (e) {
      // Cualquier otro error inesperado
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
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Correo"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Contraseña"),
              obscureText: true,
            ),
            const SizedBox(height: 24),
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
