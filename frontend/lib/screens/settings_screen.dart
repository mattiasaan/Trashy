import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Impostazioni',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? AuraColors.textMainDark : AuraColors.textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalizza la tua esperienza Aura',
            style: TextStyle(color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://via.placeholder.com/150')),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Elena Rossi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AuraColors.textMainDark : AuraColors.textMain)),
                    Text('elena.rossi@auramail.com', style: TextStyle(fontSize: 12, color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aspetto & Tema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AuraColors.textMainDark : AuraColors.textMain)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ThemeButton(label: 'Chiaro', icon: Icons.wb_sunny_outlined, isSelected: !isDark),
                    _ThemeButton(label: 'Scuro', icon: Icons.nightlight_outlined, isSelected: isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;

  const _ThemeButton({required this.label, required this.icon, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AuraColors.primaryGreen.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? AuraColors.primaryGreen : Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}