// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import '../themes/app_colors.dart'; // Assicurati che sia '../theme' o '../themes' in base al tuo progetto
import 'assistant_screen.dart';
import 'maps_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // Di default partiamo su Maps

  final List<Widget> _screens = [
    AssistantScreen(),
    MapsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AuraColors.darkBg : AuraColors.lightBg,
      body: Stack(
        children: [
          // Schermata attiva
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Barra di navigazione fluttuante compatta e più staccata dal fondo
          Positioned(
            left: 48,
            right: 48,
            bottom: 22, // Distanza aumentata dal fondo dello schermo
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', isDark),
                  _buildNavItem(1, Icons.map_outlined, Icons.map, 'Maps', isDark),
                  _buildNavItem(2, Icons.settings_outlined, Icons.settings, 'Settings', isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget per i singoli elementi della navbar
  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final primaryColor = isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen;
    final unselectedColor = isDark ? AuraColors.textMutedDark : AuraColors.textMuted;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: isSelected ? primaryColor : unselectedColor,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}