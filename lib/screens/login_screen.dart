import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'BottomTab_Screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = cred.user;
      if (user == null) return;

      // Comprueba el estado en Firestore
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final estado = doc.data()?['estado'] as String? ?? 'pendiente';

      if (estado == 'pendiente') {
        // Cierra sesión y avisa
        await FirebaseAuth.instance.signOut();
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cuenta pendiente'),
            content: const Text(
                'Tu cuenta todavía está pendiente de aprobación por un administrador.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
        return;
      }

      // Si está aceptado, navega al home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomtabScreen()),
      );

    } on FirebaseAuthException catch (e) {
      String mensaje;
      switch (e.code) {
        case 'invalid-email':
          mensaje = 'El correo está mal formado.';
          break;
        case 'user-not-found':
          mensaje = 'No existe ninguna cuenta con ese correo.';
          break;
        case 'wrong-password':
          mensaje = 'Contraseña incorrecta.';
          break;
        case 'user-disabled':
          mensaje = 'Esta cuenta ha sido deshabilitada.';
          break;
        case 'network-request-failed':
          mensaje = 'Error de red. Verifica tu conexión.';
          break;
        default:
          mensaje = 'Error al iniciar sesión. Inténtalo de nuevo.';
      }
      // Mostrar diálogo de error
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error de inicio de sesión"),
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
      // Error inesperado
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
        title: const Text("Inicio Sesión"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              onPressed: login,
              child: const Text("Inicio de sesión"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("¿No tienes cuenta? "),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    "Regístrate aquí",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
