import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

// Pantalla que muestra la galería de fotos del concurso
class GaleriaScreen extends StatefulWidget {
  const GaleriaScreen({super.key});

  @override
  State<GaleriaScreen> createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  bool isAdmin = false;
  bool cargandoRol = true;
  String? currentUid;
  bool hasUploaded = false;
  bool concursoActivo = false;
  String temaActual = '';
  bool cargandoTema = true;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid;
    _verificarAdmin();
    _checkUploadStatus();
    _cargarTemaConcurso();
    _verificarConcursoActivo();
  }

  // Verifica si hay un concurso activo
  Future<void> _verificarConcursoActivo() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('concursos')
        .where('estado', isEqualTo: 'en_curso')
        .limit(1)
        .get();

    setState(() {
      concursoActivo = snapshot.docs.isNotEmpty;
    });
  }

  // Verifica si el usuario actual tiene rol "admin"
  Future<void> _verificarAdmin() async {
    if (currentUid == null) {
      setState(() => cargandoRol = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUid)
        .get();
    setState(() {
      isAdmin = doc.data()?['rango'] == 'admin';
      cargandoRol = false;
    });
  }

   // Revisa si el usuario ya subió una foto
  Future<void> _checkUploadStatus() async {
    if (currentUid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('galeria')
        .where('usuarioId', isEqualTo: currentUid)
        .limit(1)
        .get();
    setState(() {
      hasUploaded = snap.docs.isNotEmpty;
    });
  }

  
  // Carga el tema del concurso activo
  Future<void> _cargarTemaConcurso() async {
    final snap = await FirebaseFirestore.instance
        .collection('concursos')
        .where('estado', isEqualTo: 'en_curso')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();
      temaActual = data['tema'] as String? ?? '';
    }
    setState(() => cargandoTema = false);
  }

  // Obtiene el stream de fotos según si es admin o no
  Stream<QuerySnapshot> _obtenerFotos() {
    final coll = FirebaseFirestore.instance.collection('galeria');
    if (isAdmin) {
      return coll.orderBy('timestamp', descending: true).snapshots();
    }
    return coll
        .where('estado', isEqualTo: 'aceptado')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Votar una foto (solo si no ha votado antes)
  Future<void> _votarFoto(String id, List<dynamic> votedBy) async {
    if (currentUid == null || votedBy.contains(currentUid)) return;
    await FirebaseFirestore.instance.collection('galeria').doc(id).update({
      'votos': FieldValue.increment(1),
      'votedBy': FieldValue.arrayUnion([currentUid]),
    });
  }

  // Admin: aceptar una foto (cambiar estado a "aceptado")
  Future<void> _aceptarFoto(String id) async {
    await FirebaseFirestore.instance
        .collection('galeria')
        .doc(id)
        .update({'estado': 'aceptado'});
  }

  // Admin: rechazar una foto (eliminarla)
  Future<void> _rechazarFoto(String id) async {
    await FirebaseFirestore.instance.collection('galeria').doc(id).delete();
  }

  // Subir una foto a la galería
  Future<void> _subirFoto() async {
  if (hasUploaded) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solo puedes subir una foto.')),
    );
    return;
  }

  final picker = ImagePicker();
  final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);
  if (imagen == null || currentUid == null) return;

  final Uint8List imageBytes = await imagen.readAsBytes();
  final String base64Image = base64Encode(imageBytes);

  final userDoc = await FirebaseFirestore.instance
      .collection('usuarios')
      .doc(currentUid)
      .get();
  final uploaderName = userDoc.data()?['nombre'] as String? ?? 'Desconocido';

  await FirebaseFirestore.instance.collection('galeria').add({
    'imagen': base64Image,
    'estado': 'pendiente',
    'timestamp': FieldValue.serverTimestamp(),
    'usuarioId': currentUid,
    'usuarioNombre': uploaderName,
    'votos': 0,
    'votedBy': [],
  });

  setState(() {
    hasUploaded = true;
  });
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Foto enviada para revisión.')),
  );
}

  @override
  Widget build(BuildContext context) {
    if (cargandoRol) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Expanded(child: Text('Galería de fotos')),
            if (temaActual.isNotEmpty)
              Text('Tema: $temaActual', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _obtenerFotos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No hay fotos disponibles.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final imageId = doc.id;
              final estado = data['estado'] as String? ?? 'pendiente';
              final imageBytes = base64Decode(data['imagen'] as String? ?? '');
              final uploaderName = data['usuarioNombre'] as String? ?? 'Desconocido';
              final votos = data['votos'] as int? ?? 0;
              final votedBy = List<String>.from(data['votedBy'] as List<dynamic>? ?? []);
              final hasVoted = currentUid != null && votedBy.contains(currentUid);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    // Imagen cargada
                    Positioned.fill(child: Image.memory(imageBytes, fit: BoxFit.cover)),
                    // Botón de votos
                    Positioned(
                      bottom: 40,
                      right: 8,
                      child: Row(
                        children: [
                          Text('$votos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: Icon(Icons.thumb_up, color: hasVoted ? Colors.blue : Colors.white),
                            onPressed: hasVoted ? null : () => _votarFoto(imageId, votedBy),
                          ),
                        ],
                      ),
                    ),
                     // Nombre del autor
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        color: Colors.black.withOpacity(0.5),
                        child: Text(
                          'Subido por: $uploaderName',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Botones de aceptar/rechazar (solo para admins)
                    if (isAdmin && estado == 'pendiente')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          children: [
                            IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _aceptarFoto(imageId)),
                            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _rechazarFoto(imageId)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
       // Botón para subir foto
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: !concursoActivo || hasUploaded ? null : _subirFoto,
          icon: const Icon(Icons.add_a_photo),
          label: Text(concursoActivo
            ? (hasUploaded ? 'Ya has subido una foto' : 'Añadir foto')
            : 'No hay concurso activo'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: hasUploaded ? Colors.grey : Colors.orange,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
