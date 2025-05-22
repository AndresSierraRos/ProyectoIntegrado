import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'Resultado_concurso_screen.dart';

/// Pantalla que lista todos los concursos (activos y finalizados),
/// ordenados por fecha de inicio descendente. Permite al usuario
/// pulsar sobre uno para ver su resultado en pantalla detallada.
class ConcursosScreen extends StatelessWidget {
  const ConcursosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra superior con título
      appBar: AppBar(title: const Text('Concursos')),
      body: StreamBuilder<QuerySnapshot>(
        // Escucha en tiempo real la colección 'concursos',
        // ordenados de más reciente a más antiguo
        stream: FirebaseFirestore.instance
            .collection('concursos')
            .orderBy('inicio', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          // Mientras no llegan datos, mostrar indicador
          if (!snap.hasData) return const CircularProgressIndicator();

          final docs = snap.data!.docs; // Documentos de concursos

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              // Cada documento lo convertimos a Map<String, dynamic>
              final c = docs[i].data() as Map<String, dynamic>;

              // Campos del documento
              final estado = c['estado'] as String;
              final inicio = (c['inicio'] as Timestamp).toDate();
              final fin = c['fin'] != null
                  ? (c['fin'] as Timestamp).toDate()
                  : null;

              return ListTile(
                // Título que muestra la fecha de inicio
                title: Text('Concurso iniciado ${inicio.toLocal()}'),
                // Subtítulo con estado: "En curso" o fecha de finalización
                subtitle: Text(
                  estado == 'en_curso'
                      ? 'En curso'
                      : 'Finalizado: ${fin!.toLocal()}',
                ),
                // Icono de flecha para indicar navegación
                trailing: const Icon(Icons.arrow_forward_ios),
                // Al pulsar, navega a la pantalla de resultados de ese concurso
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultadoConcursoScreen(
                        concursoDoc: docs[i],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
