import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'galeria_screen.dart';
import 'ranking_screen.dart';

/// Pantalla principal con pestañas inferiores (bottom tabs)
/// que permiten navegar entre Perfil, Galería y Ranking.
class BottomtabScreen extends StatefulWidget {
  const BottomtabScreen({super.key});

  @override
  State<BottomtabScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<BottomtabScreen> {
  int _selectedIndex = 0; // Índice de la pestaña actualmente activa

  // Lista de widgets para cada pestaña, en el mismo orden que los items del BottomNavigationBar
  final List<Widget> _pantallas = const [
    ProfileScreen(),   // Índice 0 → Perfil
    GaleriaScreen(),   // Índice 1 → Galería
    RankingScreen(),   // Índice 2 → Ranking
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El cuerpo muestra la pantalla correspondiente al índice seleccionado
      body: _pantallas[_selectedIndex],
      // Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,            // Resalta el tab activo
        onTap: (index) => setState(() =>         // Al pulsar un tab, actualiza el índice
            _selectedIndex = index),
        selectedItemColor: Colors.orange,        // Color del icono/texto seleccionado
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),            // Ícono para Perfil
            label: 'Perfil',                     // Etiqueta bajo el ícono
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),     // Ícono para Galería
            label: 'Galería',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),       // Ícono para Ranking
            label: 'Ranking',
          ),
        ],
      ),
    );
  }
}
