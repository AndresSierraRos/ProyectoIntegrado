import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'BottomTab_Screen.dart';

/// Pantalla de inicio de sesión.
/// Permite al usuario autenticarse con email/contraseña,
/// verifica que la cuenta esté aprobada en Firestore y maneja errores.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para los campos de texto
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  /// Método principal de login:
  /// 1. Intenta autenticar con Firebase Auth.
  /// 2. Verifica en Firestore el campo 'estado' (pendiente/aceptado).
  /// 3. Si está pendiente, cierra sesión y alerta al usuario.
  /// 4. Si está aceptado, navega al BottomTabScreen.
  /// 5. Captura y muestra mensajes amigables para errores de FirebaseAuth.
  Future<void> login() async {
    try {
      // 1) Autenticación con email y contraseña
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = cred.user;
      if (user == null) return; // Si no devuelve usuario, termina

      // 2) Consultar estado en Firestore
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final estado = doc.data()?['estado'] as String? ?? 'pendiente';

      // 3) Si está pendiente, cerrar sesión y mostrar diálogo
      if (estado == 'pendiente') {
        await FirebaseAuth.instance.signOut();
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cuenta pendiente'),
            content: const Text(
              'Tu cuenta todavía está pendiente de aprobación por un administrador.'
            ),
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

      // 4) Estado aceptado: navegar al Home (BottomTabScreen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomtabScreen()),
      );

    }
    // Manejo de errores específicos de Firebase Auth
    on FirebaseAuthException catch (e) {
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
      // Mostrar diálogo de error con mensaje amigable
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
    }
    // Captura cualquier otro error no previsto
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
      // AppBar sin flecha de volver
      appBar: AppBar(
        title: const Text("Inicio Sesión"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Campo de correo
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Correo"),
            ),
            // Campo de contraseña (oculta texto)
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Contraseña"),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            // Botón de inicio de sesión
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
            // Pie: enlace a registro
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("¿No tienes cuenta? "),
                GestureDetector(
                  onTap: () {
                    // Navegar a pantalla de registro
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
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
