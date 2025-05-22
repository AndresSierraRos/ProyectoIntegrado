import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Pantalla para que el administrador gestione los usuarios:
/// - Ver la lista completa de usuarios.
/// - Aceptar cuentas pendientes.
/// - Eliminar usuarios y sus fotos asociadas.
class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra superior con el título de la pantalla
      appBar: AppBar(title: const Text("Gestionar usuarios")),
      // Cuerpo: escucha en tiempo real la colección 'usuarios'
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (ctx, snap) {
          // Mientras no haya datos, mostrar indicador
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs; // Lista de documentos de usuarios

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final u = docs[i]; // Documento individual
              final estado = u['estado'] as String? ?? 'pendiente';

              return ListTile(
                // Mostrar nombre o correo si no hay nombre
                title: Text(u['nombre'] ?? u['email']),
                // Subtítulo con el estado actual de la cuenta
                subtitle: Text("Estado: $estado"),
                // Botones de acción: aceptar (si está pendiente) y eliminar
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Si el usuario está pendiente, mostrar botón de aceptar
                    if (estado == 'pendiente')
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: 'Aceptar usuario',
                        onPressed: () {
                          // Cambia el campo 'estado' a 'aceptado'
                          FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(u.id)
                              .update({'estado': 'aceptado'});
                        },
                      ),
                    // Botón de eliminar usuario
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar usuario',
                      onPressed: () async {
                        // Primero mostrar diálogo de confirmación
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar usuario'),
                            content: Text(
                              '¿Seguro que quieres eliminar a '
                              '${u['nombre'] ?? u['email']}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('No'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Sí'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;

                        // Uso de batch para operaciones atómicas
                        final batch = FirebaseFirestore.instance.batch();

                        // 1) Eliminar todas las fotos de la galería subidas por este usuario
                        final fotosQuery = await FirebaseFirestore.instance
                            .collection('galeria')
                            .where('usuarioId', isEqualTo: u.id)
                            .get();
                        for (final fotoDoc in fotosQuery.docs) {
                          batch.delete(fotoDoc.reference);
                        }

                        // 2) Eliminar el documento del propio usuario
                        batch.delete(u.reference);

                        // 3) (Opcional) eliminar su foto de perfil de Storage
                        //    No se puede incluir en el mismo batch de Firestore.
                        // final fotoRef = FirebaseStorage.instance
                        //     .ref().child('perfiles/${u.id}.jpg');
                        // await fotoRef.delete();

                        // 4) Ejecutar todas las eliminaciones de Firestore en un solo commit
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
