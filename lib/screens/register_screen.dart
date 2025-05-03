import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyectointegrado/screens/home_screen.dart';

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
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Guardar en Firestore
      await FirebaseFirestore.instance.collection("usuarios").doc(userCredential.user!.uid).set({
        "uid": userCredential.user!.uid,
        "nombre": nameController.text.trim(),
        "email": emailController.text.trim(),
        "fechaRegistro": Timestamp.now(),
        'descripcion': '',
        'fotoPerfilBase64': null,
        'rango': 'usuario',
        "estado": "pendiente",
      });

       // Cerramos su sesión y avisamos que está pendiente
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
      Navigator.pop(context); // Volvemos a login
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro"),
      automaticallyImplyLeading: false,),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Correo")),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Contraseña"), obscureText: true),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: register, child: const Text("Registrarse"),
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
