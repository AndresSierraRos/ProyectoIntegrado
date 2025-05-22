import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Pantalla que muestra el resultado final de un concurso,
/// usando los datos ya calculados y almacenados en Firestore.
class ResultadoConcursoScreen extends StatelessWidget {
  final QueryDocumentSnapshot concursoDoc;

  const ResultadoConcursoScreen({
    required this.concursoDoc, 
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extraemos los datos del documento de Firestore
    final data = concursoDoc.data() as Map<String, dynamic>;
    // Obtenemos la lista 'rankingFinal' o una lista vacía si no existe
    final List ranking = data['rankingFinal'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado concurso'),
      ),
      body: Column(
        children: [
          // Bloque TOP 3: se muestra si hay al menos 1 participante
          if (ranking.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                // Generamos entre 1 y 3 widgets según cuántos haya
                ranking.length < 3 ? ranking.length : 3,
                (i) {
                  final item = ranking[i] as Map<String, dynamic>;

                  // Intentamos decodificar la foto de perfil en base64
                  Widget avatar;
                  try {
                    final bytes = base64Decode(item['imagen'] as String);
                    avatar = CircleAvatar(
                      radius: 40,
                      backgroundImage: MemoryImage(bytes),
                    );
                  } catch (_) {
                    // Si falla (null, formato incorrecto...), mostramos un avatar genérico
                    avatar = const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    );
                  }

                  return Column(
                    children: [
                      avatar,
                      const SizedBox(height: 4),
                      // Número de puesto + nombre
                      Text(
                        '#${i + 1} ${item['nombre']}',
                        textAlign: TextAlign.center,
                      ),
                      // Conteo de votos
                      Text('${item['votos']} votos'),
                    ],
                  );
                },
              ),
            ),
            const Divider(), // Separador tras el top 3
          ] else ...[
            // Si no hay participantes, mostramos un mensaje informativo
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hubo participantes en este concurso.',
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Resto del ranking (puestos 4 en adelante)
          Expanded(
            child: ranking.length > 3
                ? ListView.builder(
                    itemCount: ranking.length - 3,
                    itemBuilder: (ctx, idx) {
                      final item = ranking[idx + 3] as Map<String, dynamic>;
                      return ListTile(
                        // Mostrar posición (4, 5, 6...)
                        leading: Text('#${idx + 4}'),
                        // Nombre del participante
                        title: Text(item['nombre'] as String),
                        // Votos obtenidos
                        trailing: Text('${item['votos']}'),
                      );
                    },
                  )
                : const SizedBox.shrink(), // Si no hay más de 3, no mostramos nada
          ),
        ],
      ),
    );
  }
}