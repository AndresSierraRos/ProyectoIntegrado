
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestionar usuarios")),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final u = docs[i];
              final estado = u['estado'] as String? ?? 'pendiente';
              return ListTile(
                title: Text(u['nombre'] ?? u['email']),
                subtitle: Text("Estado: $estado"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (estado == 'pendiente')
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: 'Aceptar usuario',
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(u.id)
                              .update({'estado': 'aceptado'});
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar usuario',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar usuario'),
                            content: Text('¿Seguro que quieres eliminar a ${u['nombre'] ?? u['email']}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
                            ],
                          ),
                        );
                        if (confirm != true) return;

                        final batch = FirebaseFirestore.instance.batch();

                        // 1) Eliminar todas las fotos de la galería de este usuario
                        final fotosQuery = await FirebaseFirestore.instance
                            .collection('galeria')
                            .where('usuarioId', isEqualTo: u.id)
                            .get();
                        for (final fotoDoc in fotosQuery.docs) {
                          batch.delete(fotoDoc.reference);
                        }

                        // 2) Eliminar el documento de usuarios
                        batch.delete(u.reference);

                        // 3) (Opcional) eliminar su foto de perfil almacenada en Storage
                        // final fotoRef = FirebaseStorage.instance.ref().child('perfiles/${u.id}.jpg');
                        // await fotoRef.delete();  // no va en el batch

                        // 4) Ejecutar el batch
                        await batch.commit();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
