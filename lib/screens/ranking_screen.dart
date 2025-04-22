import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  bool _loading = true;
  List<_RankItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  /// Obtiene fotos aceptadas sin orden en Firestore, y luego ordena en cliente.
  Future<void> _loadRanking() async {
    setState(() => _loading = true);

    // Obtener todas las fotos aceptadas
    final snapshot = await FirebaseFirestore.instance
        .collection('galeria')
        .where('estado', isEqualTo: 'aceptado')
        .get();

    // Transformar en lista de items con votos
    final List<_RankItem> items = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final votos = data['votos'] as int? ?? 0;
      final userId = data['usuarioId'] as String?;
      String nombre = 'Desconocido';
      String? fotoBase64;

      if (userId != null) {
        final userDoc =
            await FirebaseFirestore.instance.collection('usuarios').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null) {
          nombre = userData['nombre'] as String? ?? nombre;
          fotoBase64 = userData['fotoPerfilBase64'] as String?;
        }
      }

      items.add(_RankItem(
        nombre: nombre,
        votos: votos,
        fotoBase64: fotoBase64,
      ));
    }

    // Ordenar cliente por votos desc
    items.sort((a, b) => b.votos.compareTo(a.votos));

    // Tomar top 10
    final top10 = items.length > 10 ? items.sublist(0, 10) : items;

    setState(() {
      _items = top10;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP hasta 3 (incluso si <3)
            if (_items.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  _items.length < 3 ? _items.length : 3,
                  (i) {
                    final item = _items[i];
                    final bytes = item.fotoBase64 != null
                        ? base64Decode(item.fotoBase64!)
                        : null;
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                            backgroundImage: bytes != null ? MemoryImage(bytes) : null,
                            backgroundColor: bytes != null ? null : Colors.grey,
                            child: bytes == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
                        ),
                        const SizedBox(height: 8),
                        Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(item.nombre),
                        Text('${item.votos} votos'),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Resto 4 a 10
            Expanded(
              child: ListView.builder(
                itemCount: _items.length > 3 ? _items.length - 3 : 0,
                itemBuilder: (context, index) {
                  final item = _items[index + 3];
                  return ListTile(
                    leading: Text('#${index + 4}'),
                    title: Text(item.nombre),
                    trailing: Text('${item.votos} votos'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankItem {
  final String nombre;
  final int votos;
  final String? fotoBase64;

  _RankItem({
    required this.nombre,
    required this.votos,
    this.fotoBase64,
  });
}
