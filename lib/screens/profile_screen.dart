import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:proyectointegrado/screens/ManageUsersScreen.dart';
import 'login_screen.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isAdmin = false;
  String nombre = "";
  String descripcion = "";
  String? fotoPerfilUrl;
  bool cargando = true; 
  TextEditingController descripcionController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        nombre = doc.data()!.containsKey('nombre') ? doc['nombre'] : '';
        descripcion = doc.data()!.containsKey('descripcion') ? doc['descripcion'] : '';
        fotoPerfilUrl = doc['fotoPerfilBase64'] as String?;
        descripcionController.text = descripcion;
        isAdmin = (data['rango'] as String?) == 'admin';
        cargando = false;
      });
      } else {
        setState(() {
          cargando = false;
        });
      }
    }
    Future<void> editarNombre() async {
    TextEditingController nuevoNombreController = TextEditingController(text: nombre);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar nombre"),
          content: TextField(
            controller: nuevoNombreController,
            decoration: const InputDecoration(
              hintText: "Escribe tu nuevo nombre",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final nuevoNombre = nuevoNombreController.text.trim();
                if (nuevoNombre.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(user!.uid)
                      .update({'nombre': nuevoNombre});
                  setState(() {
                    nombre = nuevoNombre;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }


  Future<void> actualizarDescripcion() async {
    await FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).update({
      'descripcion': descripcionController.text.trim(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Descripción actualizada")));
  }

  Future<void> cambiarFotoPerfil() async {
  final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);
    if (imagen != null) {
      final Uint8List imageBytes = await imagen.readAsBytes();
      final String base64SinPrefijo = base64Encode(imageBytes);

      await FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).update({
        'fotoPerfilBase64': base64SinPrefijo,
      });

      setState(() {
        fotoPerfilUrl = base64SinPrefijo;
      });
    }
    }

  Future<void> eliminarCuenta() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final uid = user.uid;

  // Confirmación
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Eliminar cuenta"),
      content: const Text("¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer."),
      actions: [
        TextButton(
          child: const Text("No"),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ElevatedButton(
          child: const Text("Sí, eliminar"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  if (confirmar != true) return;

  try {
    // Eliminar foto de perfil si existe
    final fotoRef = FirebaseStorage.instance.ref().child("perfiles/$uid.jpg");
    try {
      await fotoRef.delete();
    } catch (e) {
      print("No se encontró la foto o ya estaba eliminada.");
    }

    // Eliminar datos en Firestore
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).delete();

    // Eliminar cuenta en Auth
    await user.delete();

    // Redirigir al login
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  } catch (e) {
    print("Error eliminando la cuenta: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No se pudo eliminar la cuenta. Intenta iniciar sesión de nuevo si es necesario.")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text("Perfil")
      ),
     body: cargando
    ? const Center(child: CircularProgressIndicator())
    : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
           GestureDetector(
                onTap: cambiarFotoPerfil,
                child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: (() {
                  if (fotoPerfilUrl == null || fotoPerfilUrl!.isEmpty) {
                    return null as ImageProvider<Object>?;
                  }
                  try {
                    final str = fotoPerfilUrl!;
                    if (str.startsWith('data:image') || str.length > 1000) {
                      final comma = str.indexOf(',');
                      final payload = comma >= 0 ? str.substring(comma + 1) : str;
                      final bytes = base64Decode(payload);
                      return MemoryImage(bytes);
                    } else {
                      return NetworkImage(str);
                    }
                  } catch (e) {
                    print("Error al cargar imagen de perfil: $e");
                    return null;
                  }
                })(),
                child: (fotoPerfilUrl == null || fotoPerfilUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: editarNombre,
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: "Editar nombre",
                ),
              ],
          ),

            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Descripción personal:", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextField(
              controller: descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Escribe algo sobre ti...",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: actualizarDescripcion,
              child: const Text("Guardar"),
            ),
            const Spacer(),
            if (isAdmin) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.manage_accounts),
                label: const Text("Gestionar usuarios"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text("Cerrar sesión"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
