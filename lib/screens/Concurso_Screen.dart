import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'Resultado_concurso_screen.dart';
class ConcursosScreen extends StatelessWidget {
  const ConcursosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Concursos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('concursos')
            .orderBy('inicio', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const CircularProgressIndicator();
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final c = docs[i].data() as Map<String, dynamic>;
              final estado = c['estado'] as String;
              final inicio = (c['inicio'] as Timestamp).toDate();
              final fin = c['fin'] != null
                  ? (c['fin'] as Timestamp).toDate()
                  : null;
              return ListTile(
                title: Text('Concurso iniciado ${inicio.toLocal()}'),
                subtitle: Text(estado == 'en_curso'
                    ? 'En curso'
                    : 'Finalizado: ${fin!.toLocal()}'),
                trailing: const Icon(Icons.arrow_forward_ios),
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