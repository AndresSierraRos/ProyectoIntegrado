import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Concurso_Screen.dart';
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  bool _loading = true;
  List<_RankItem> _items = [];

  // Nuevo: gestión de rol Admin
  bool _cargandoRol = true;
  bool _isAdmin = false;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _verificarAdmin();
    _loadRanking();
  }

  Future<void> _verificarAdmin() async {
    if (_currentUid == null) {
      setState(() => _cargandoRol = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_currentUid)
        .get();
    setState(() {
      _isAdmin = (doc.data()?['rango'] as String?) == 'admin';
      _cargandoRol = false;
    });
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

  Future<void> _iniciarConcurso() async {
  // Verifica que no haya ya uno en curso
  final enCurso = await FirebaseFirestore.instance
      .collection('concursos')
      .where('estado', isEqualTo: 'en_curso')
      .limit(1)
      .get();
  if (enCurso.docs.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ya hay un concurso en curso')),
    );
    return;
  }

  // Pedir tema al admin
  final temaController = TextEditingController();
  final tema = await showDialog<String?>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Tema del nuevo concurso'),
      content: TextField(
        controller: temaController,
        decoration: const InputDecoration(hintText: 'Escribe el tema aquí'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, temaController.text.trim()), child: const Text('Crear')),
      ],
    ),
  );

  if (tema == null || tema.isEmpty) return;  // si canceló o vacío, no iniciar

  // Crear nuevo concurso con tema
  await FirebaseFirestore.instance.collection('concursos').add({
    'inicio': FieldValue.serverTimestamp(),
    'fin': null,
    'estado': 'en_curso',
    'tema': tema,
    'rankingFinal': [],
  });

  // Vaciar galería
  final galSnap = await FirebaseFirestore.instance.collection('galeria').get();
  final batch = FirebaseFirestore.instance.batch();
  for (var f in galSnap.docs) batch.delete(f.reference);
  await batch.commit();

  await _loadRanking();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Concurso iniciado con tema: "$tema"')),
  );
}

  Future<void> _terminarConcurso() async {
    final snap = await FirebaseFirestore.instance
        .collection('concursos')
        .where('estado', isEqualTo: 'en_curso')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay concurso en curso')),
      );
      return;
    }
    final concursoRef = snap.docs.first.reference;
    final galSnap = await FirebaseFirestore.instance
        .collection('galeria')
        .where('estado', isEqualTo: 'aceptado')
        .get();
    final fotos = galSnap.docs.map((doc) {
      final d = doc.data();
      return {
        'usuarioId': d['usuarioId'],
        'nombre': d['usuarioNombre'],
        'votos': d['votos'] as int? ?? 0,
        'imagen': d['imagen'],
      };
    }).toList();
    fotos.sort((a, b) => (b['votos'] as int).compareTo(a['votos'] as int));
    await concursoRef.update({
      'estado': 'finalizado',
      'fin': FieldValue.serverTimestamp(),
      'rankingFinal': fotos,
    });
    // vaciar galería
    final batch = FirebaseFirestore.instance.batch();
    for (var f in galSnap.docs) batch.delete(f.reference);
    await batch.commit();

    await _loadRanking();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Concurso finalizado y galería vaciada')),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking'),
      automaticallyImplyLeading: false,
       actions: [
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Ver concursos',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConcursosScreen()),
              ),
            ),
        ],
      ),
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
       bottomNavigationBar: _isAdmin
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _iniciarConcurso,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('Iniciar concurso'),
                    ),  
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _terminarConcurso,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Terminar concurso'),
                    ),
                  ),
                ],
              ),
            )
          : null,
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
