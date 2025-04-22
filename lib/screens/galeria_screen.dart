import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

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
  String tema = 'Cargando...';
  bool cargandoTema = true;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid;
    _verificarAdmin();
    _checkUploadStatus();
    _cargarTema();
  }

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

  Future<void> _cargarTema() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('rally')
        .get();
    setState(() {
      tema = doc.exists ? (doc.data()?['tema'] as String? ?? '') : '';
      cargandoTema = false;
    });
  }

  Future<void> _editarTema() async {
    final controller = TextEditingController(text: tema);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar tema del rally'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Escribe el nuevo tema'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo != null && nuevo.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('rally')
          .set({'tema': nuevo});
      setState(() {
        tema = nuevo;
      });
    }
  }

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

  Future<void> _votarFoto(String id, List<dynamic> votedBy) async {
    if (currentUid == null || votedBy.contains(currentUid)) return;
    await FirebaseFirestore.instance.collection('galeria').doc(id).update({
      'votos': FieldValue.increment(1),
      'votedBy': FieldValue.arrayUnion([currentUid]),
    });
  }

  Future<void> _aceptarFoto(String id) async {
    await FirebaseFirestore.instance
        .collection('galeria')
        .doc(id)
        .update({'estado': 'aceptado'});
  }

  Future<void> _rechazarFoto(String id) async {
    await FirebaseFirestore.instance.collection('galeria').doc(id).delete();
  }

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
    final bytes = await File(imagen.path).readAsBytes();
    final base64Image = base64Encode(bytes);
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Foto enviada para revisión.')));
  }

  @override
  Widget build(BuildContext context) {
    if (cargandoRol || cargandoTema) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galería de fotos'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Tema: ', style: TextStyle(fontSize: 16)),
                Text(tema, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: _editarTema,
                    tooltip: 'Editar tema',
                  ),
                ],
              ],
            ),
          ),
        ],
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
                    Positioned.fill(child: Image.memory(imageBytes, fit: BoxFit.cover)),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: hasUploaded ? null : _subirFoto,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Añadir foto'),
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
