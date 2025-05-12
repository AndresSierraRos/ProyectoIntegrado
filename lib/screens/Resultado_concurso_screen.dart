import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ResultadoConcursoScreen extends StatelessWidget {
  final QueryDocumentSnapshot concursoDoc;
  const ResultadoConcursoScreen({required this.concursoDoc, Key? key})
      : super(key: key);

 @override
  Widget build(BuildContext context) {
    final data = concursoDoc.data() as Map<String, dynamic>;
    final List ranking = data['rankingFinal'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado concurso')),
      body: Column(
        children: [
          // TOP hasta 3, incluso si hay menos
          if (ranking.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                ranking.length < 3 ? ranking.length : 3,
                (i) {
                  final item = ranking[i] as Map<String, dynamic>;
                  Widget avatar;
                  try {
                    final bytes = base64Decode(item['fotoPerfilBase64'] as String);
                    avatar = CircleAvatar(radius: 40, backgroundImage: MemoryImage(bytes));
                  } catch (_) {
                    avatar = const CircleAvatar(radius: 40, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white));
                  }
                  return Column(
                    children: [
                      avatar,
                      const SizedBox(height: 4),
                      Text('#${i + 1} ${item['nombre']}', textAlign: TextAlign.center),
                      Text('${item['votos']} votos'),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
          ] else ...[
            // Si no hay participantes
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hubo participantes en este concurso.', textAlign: TextAlign.center),
            ),
          ],

          // Resto (4 en adelante)
          Expanded(
            child: ranking.length > 3
                ? ListView.builder(
                    itemCount: ranking.length - 3,
                    itemBuilder: (ctx, idx) {
                      final item = ranking[idx + 3] as Map<String, dynamic>;
                      return ListTile(
                        leading: Text('#${idx + 4}'),
                        title: Text(item['nombre'] as String),
                        trailing: Text('${item['votos']}'),
                      );
                    },
                  )
                : const SizedBox.shrink(), // no muestra nada si <= 3
          ),
        ],
      ),
    );
  }
}
