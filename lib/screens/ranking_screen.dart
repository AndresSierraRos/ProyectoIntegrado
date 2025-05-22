import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Concurso_Screen.dart';

/// Pantalla que muestra el ranking actual de la galería,
/// permite a admin iniciar/terminar concursos y a todos los usuarios ver posiciones.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  bool _loading = true;            // Para mostrar indicador mientras carga datos
  List<_RankItem> _items = [];     // Lista de participantes ordenados por votos

  bool _isAdmin = false;           // Flag para saber si el usuario es administrador
  String? _currentUid;             // UID del usuario actual

  @override
  void initState() {
    super.initState();
    // Obtener UID y comprobar rol/admin, luego cargar ranking
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _verificarAdmin();
    _loadRanking();
  }

  /// Consulta Firestore para ver si el usuario actual tiene rango 'admin'
  Future<void> _verificarAdmin() async {
    if (_currentUid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_currentUid)
        .get();
    setState(() {
      _isAdmin = (doc.data()?['rango'] as String?) == 'admin';
    });
  }

  /// Carga todas las fotos con estado "aceptado", las transforma en items,
  /// recupera nombre/foto de perfil del autor, ordena por votos y toma top10.
  Future<void> _loadRanking() async {
    setState(() => _loading = true);

    // 1) Traer fotos aceptadas
    final snapshot = await FirebaseFirestore.instance
        .collection('galeria')
        .where('estado', isEqualTo: 'aceptado')
        .get();

    final List<_RankItem> items = [];
    // 2) Para cada foto, buscar datos de usuario y crear objeto _RankItem
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final votos = data['votos'] as int? ?? 0;
      final userId = data['usuarioId'] as String?;
      String nombre = 'Desconocido';
      String? fotoBase64;

      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .get();
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

    // 3) Ordenar lista de mayor a menor votos
    items.sort((a, b) => b.votos.compareTo(a.votos));
    // 4) Tomar solo los 10 primeros (o menos si hay menos)
    final top10 = items.length > 10 ? items.sublist(0, 10) : items;

    setState(() {
      _items = top10;
      _loading = false;
    });
  }

  /// Inicia un nuevo concurso:
  /// - Verifica que no haya uno en curso
  /// - Pide tema al admin vía diálogo
  /// - Crea documento en 'concursos' con estado "en_curso" y tema
  /// - Vacía la colección 'galeria' para el nuevo concurso
  Future<void> _iniciarConcurso() async {
    // 1) Comprobar concurso en curso
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

    // 2) Pedir tema al admin
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, temaController.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (tema == null || tema.isEmpty) return;

    // 3) Crear documento del concurso
    await FirebaseFirestore.instance.collection('concursos').add({
      'inicio': FieldValue.serverTimestamp(),
      'fin': null,
      'estado': 'en_curso',
      'tema': tema,
      'rankingFinal': [],
    });

    // 4) Vaciar galería
    final galSnap =
        await FirebaseFirestore.instance.collection('galeria').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var f in galSnap.docs) batch.delete(f.reference);
    await batch.commit();

    // 5) Refrescar ranking y notificar
    await _loadRanking();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Concurso iniciado con tema: "$tema"')),
    );
  }

  /// Termina el concurso en curso:
  /// - Obtiene el concurso "en_curso"
  /// - Recoge fotos aceptadas, arma lista de rankingFinal
  /// - Actualiza el concurso a "finalizado" con fin y rankingFinal
  /// - Vacía la galería
  Future<void> _terminarConcurso() async {
    // 1) Buscar concurso en curso
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

    // 2) Recoger todas las fotos aceptadas
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
    // 3) Ordenar fotos por votos descendente
    fotos.sort((a, b) => (b['votos'] as int).compareTo(a['votos'] as int));

    // 4) Actualizar concurso con fin y rankingFinal
    await concursoRef.update({
      'estado': 'finalizado',
      'fin': FieldValue.serverTimestamp(),
      'rankingFinal': fotos,
    });

    // 5) Vaciar galería de nuevo
    final batch = FirebaseFirestore.instance.batch();
    for (var f in galSnap.docs) batch.delete(f.reference);
    await batch.commit();

    // 6) Refrescar ranking y notificar
    await _loadRanking();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Concurso finalizado y galería vaciada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mientras carga datos muestra un spinner
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking'),
        automaticallyImplyLeading: false,
        actions: [
          // Botón para ver lista de concursos
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
            // Sección TOP 3 (o menos si no hay suficientes)
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
                        // Avatar con foto de perfil o placeholder
                        CircleAvatar(
                          radius: 40,
                          backgroundImage:
                              bytes != null ? MemoryImage(bytes) : null,
                          backgroundColor:
                              bytes != null ? null : Colors.grey,
                          child: bytes == null
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 40)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text('#${i + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(item.nombre),
                        Text('${item.votos} votos'),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Lista de posiciones 4 a 10
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
      // Botones de admin para iniciar/terminar concurso
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

/// Modelo que representa cada entrada en el ranking:
/// - nombre: nombre del usuario
/// - votos: número de votos obtenidos
/// - fotoBase64: cadena base64 de la foto de perfil (opcional)
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