import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'galeria_screen.dart';
import 'ranking_screen.dart';

class BottomtabScreen extends StatefulWidget {
  const BottomtabScreen({super.key});

  @override
  State<BottomtabScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<BottomtabScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pantallas = const [
    ProfileScreen(),
    GaleriaScreen(),
    RankingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantallas[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.orange,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Galería',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Ranking',
          ),
        ],
      ),
    );
  }
}
