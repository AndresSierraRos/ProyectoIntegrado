import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyectointegrado/screens/ManageUsersScreen.dart';
import 'home_screen.dart';
import 'dart:convert';

/// Pantalla de perfil donde el usuario puede ver y editar sus datos.
/// Si es administrador, también permite navegar a la gestión de usuarios.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isAdmin = false;                     // Flag si el usuario es administrador
  String nombre = "";                       // Nombre mostrado en perfil
  String descripcion = "";                  // Descripción personal
  String? fotoPerfilUrl;                    // Base64 o URL de la foto de perfil
  bool cargando = true;                     // Muestra indicador mientras carga datos
  TextEditingController descripcionController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;  // Usuario autenticado
  final picker = ImagePicker();                    // Para seleccionar imagen

  @override
  void initState() {
    super.initState();
    cargarDatos();  // Al iniciar, carga nombre, descripción, foto y rol
  }

  /// Recupera datos del usuario en Firestore:
  /// nombre, descripción, fotoPerfilBase64, y rango (admin/usuario).
  Future<void> cargarDatos() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        nombre = data['nombre'] as String? ?? '';
        descripcion = data['descripcion'] as String? ?? '';
        fotoPerfilUrl = data['fotoPerfilBase64'] as String?;
        descripcionController.text = descripcion;
        isAdmin = (data['rango'] as String?) == 'admin';
        cargando = false;
      });
    } else {
      // Si no existe el documento, simplemente escondemos el spinner
      setState(() => cargando = false);
    }
  }

  /// Muestra un diálogo para editar el nombre.
  /// Actualiza Firestore y el estado local al guardar.
  Future<void> editarNombre() async {
    final nuevoNombreController = TextEditingController(text: nombre);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar nombre"),
        content: TextField(
          controller: nuevoNombreController,
          decoration: const InputDecoration(hintText: "Escribe tu nuevo nombre"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),  // Cancelar
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevo = nuevoNombreController.text.trim();
              if (nuevo.isNotEmpty && user != null) {
                // Actualizar en Firestore
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(user!.uid)
                    .update({'nombre': nuevo});
                setState(() => nombre = nuevo);  // Actualizar UI
                Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  /// Guarda la descripción editada en Firestore y muestra un SnackBar.
  Future<void> actualizarDescripcion() async {
    if (user == null) return;
    final texto = descripcionController.text.trim();
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user!.uid)
        .update({'descripcion': texto});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Descripción actualizada")));
  }

  /// Permite al usuario escoger una imagen de la galería y la sube codificada en Base64.
  Future<void> cambiarFotoPerfil() async {
    if (user == null) return;
    final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);
    if (imagen == null) return;

    // Leer bytes y codificar a Base64
    final Uint8List imageBytes = await imagen.readAsBytes();
    final String base64SinPrefijo = base64Encode(imageBytes);

    // Guardar en Firestore
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user!.uid)
        .update({'fotoPerfilBase64': base64SinPrefijo});

    // Actualizar en UI
    setState(() => fotoPerfilUrl = base64SinPrefijo);
  }

  @override
  Widget build(BuildContext context) {
    // Mientras cargan datos, mostrar spinner
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,  // Sin botón atrás
        title: const Text("Perfil"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Avatar circular con foto o icono por defecto
            GestureDetector(
              onTap: cambiarFotoPerfil,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: (() {
                  if (fotoPerfilUrl == null || fotoPerfilUrl!.isEmpty) {
                    return null;  // Sin imagen
                  }
                  try {
                    // Si es Base64 con prefijo o largo >1000
                    final str = fotoPerfilUrl!;
                    final comma = str.indexOf(',');
                    final payload =
                        comma >= 0 ? str.substring(comma + 1) : str;
                    final bytes = base64Decode(payload);
                    return MemoryImage(bytes);
                  } catch (e) {
                    // Si falla, no muestra imagen
                    print("Error al cargar imagen de perfil: $e");
                    return null;
                  }
                })(),
                child: (fotoPerfilUrl == null || fotoPerfilUrl!.isEmpty)
                    ? const Icon(Icons.person,
                        size: 50, color: Colors.white)
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            // Nombre con botón de editar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
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

            // Campo de texto para la descripción
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Descripción personal:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
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

            // Botón para guardar descripción
            ElevatedButton(
              onPressed: actualizarDescripcion,
              child: const Text("Guardar"),
            ),

            const Spacer(),  // Empuja los botones hasta abajo

            // Si es admin, mostrar botón de gestión de usuarios
            if (isAdmin) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.manage_accounts),
                label: const Text("Gestionar usuarios"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageUsersScreen()),
                  );
                },
              ),
            ],

            const SizedBox(height: 10),

            // Botón para cerrar sesión y volver a HomeScreen
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text("Cerrar sesión"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
