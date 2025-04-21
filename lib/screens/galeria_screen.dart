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

  @override
  void initState() {
    super.initState();
    verificarAdmin();
  }

  Future<void> verificarAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      setState(() {
        isAdmin = (doc.data()?['rango'] ?? '') == 'admin';
        cargandoRol = false;
      });
    }
  }

   /// Para admin: muestra todas las fotos. Para usuario normal: solo aceptadas.
  Stream<QuerySnapshot> obtenerFotos() {
    final coll = FirebaseFirestore.instance.collection('galeria');
    if (isAdmin) {
      return coll.orderBy('timestamp', descending: true).snapshots();
    } else {
      return coll
          .where('estado', isEqualTo: 'aceptado')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Future<void> aceptarFoto(String id) async {
    await FirebaseFirestore.instance
        .collection('galeria')
        .doc(id)
        .update({'estado': 'aceptado'});
  }

  Future<void> rechazarFoto(String id) async {
    await FirebaseFirestore.instance.collection('galeria').doc(id).delete();
  }

   Future<void> votarFoto(String id, List<dynamic> votedBy) async {
    if (currentUid == null) return;
    if (votedBy.contains(currentUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya has votado esta foto.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('galeria').doc(id).update({
        'votos': FieldValue.increment(1),
        'votedBy': FieldValue.arrayUnion([currentUid])
      });
      // Retroalimentación al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voto registrado.')),
      );
      print('Votado: \$id por \$currentUid');
    } catch (e) {
      print('Error en votarFoto: \$e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al registrar tu voto.')), 
      );
    }
  }

  Future<void> subirFoto() async {
    final picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);

    if (imagen != null) {
      final bytes = await File(imagen.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      String uploaderName = '';
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .get();
        uploaderName = (userDoc.data()?['nombre'] as String?) ?? '';
      }

      await FirebaseFirestore.instance.collection('galeria').add({
        'imagen': base64Image,
        'estado': 'pendiente',
        'timestamp': FieldValue.serverTimestamp(),
        'usuarioId': uid,
        'usuarioNombre': uploaderName,
        'votos': 0,
        'votedBy': [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto enviada para revisión.')),
      );
    }
  }

  Widget _uploaderNameWidget(String? storedName, String? userId) {
    if (storedName != null && storedName.isNotEmpty) {
      return Text(
        'Subido por: $storedName',
        style: const TextStyle(
            color: Colors.white, fontSize: 12),
        textAlign: TextAlign.center,
      );
    }
    if (userId == null) {
      return const Text(
        'Subido por: Desconocido',
        style: TextStyle(
            color: Colors.white, fontSize: 12),
        textAlign: TextAlign.center,
      );
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data?.exists == true) {
          final name = (snapshot.data?.data() as Map<String, dynamic>?)?['nombre'] as String?;
          return Text(
            'Subido por: ${name ?? 'Desconocido'}',
            style: const TextStyle(
                color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          );
        }
        return const Text(
          'Subido por: ...',
          style: TextStyle(
              color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
        );
      },
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
        title: const Text('Galería de fotos'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: obtenerFotos(),
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
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final estado = data['estado'] as String? ?? 'pendiente';
              final imageBase64 = data['imagen'] as String? ?? '';
              final imageBytes = base64Decode(imageBase64);
              final storedName = data['usuarioNombre'] as String?;
              final userId = data['usuarioId'] as String?;
              final votos = data['votos'] as int? ?? 0;
              final votedBy = data['votedBy'] as List<dynamic>? ?? [];
              final hasVoted = currentUid != null && votedBy.contains(currentUid);

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                     Positioned(
                      bottom: 30,
                      right: 8,
                      child: Row(
                        children: [
                          Text(
                            '$votos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.thumb_up,
                              color: hasVoted ? Colors.blue : Colors.white,
                            ),
                              onPressed: () async {
                              // Registro simplificado sin comprobación
                              await FirebaseFirestore.instance
                                  .collection('galeria')
                                  .doc(doc.id)
                                  .update({'votos': FieldValue.increment(1)});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Voto registrado.')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        color: Colors.black.withOpacity(0.5),
                        child: _uploaderNameWidget(storedName, userId),
                      ),
                    ),
                     if (isAdmin && estado == 'pendiente')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check,
                                  color: Colors.green),
                              onPressed: () => aceptarFoto(doc.id),
                              tooltip: 'Aceptar',
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.red),
                              onPressed: () => rechazarFoto(doc.id),
                              tooltip: 'Rechazar',
                            ),
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
          onPressed: subirFoto,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Añadir foto'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50), // ocupa todo el ancho
            backgroundColor: Colors.orange,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
