// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themeMode = 'Sistema'; // Chiaro, Scuro, Sistema
  String _selectedPalette = 'Pino'; // Pino, Cotto, Sabbia, Terra
  bool _materialYou = true;
  String _unitSystem = 'km'; // km, miglia
  String _mapSize = 'vettoriale'; // vettoriale, 3d

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AuraColors.darkCard : AuraColors.lightCard;
    final textColor = isDark ? AuraColors.textMainDark : AuraColors.textMain;
    final mutedColor = isDark ? AuraColors.textMutedDark : AuraColors.textMuted;
    final primaryColor = isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen;
    final surfaceColor = isDark ? AuraColors.darkSurface : AuraColors.lightSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), // Spazio per la bottom nav fluttuante
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intestazione
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impostazioni',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Personalizza la tua esperienza Aura',
                        style: TextStyle(
                          fontSize: 14,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.settings, color: primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- CARD 1: ASPETTO & TEMA ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, color: primaryColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aspetto & Tema',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Tonalità organiche e contrasto',
                                style: TextStyle(fontSize: 12, color: mutedColor),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'M3 Expressive',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Selettore Tema
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          _buildThemeSegment('Chiaro', Icons.wb_sunny_outlined, isDark),
                          _buildThemeSegment('Scuro', Icons.nightlight_outlined, isDark),
                          _buildThemeSegment('Sistema', Icons.brightness_auto, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tavolozza d\'Autore Aura',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: mutedColor),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPaletteOption('Pino', const Color(0xFF1E5A44), true),
                        _buildPaletteOption('Cotto', const Color(0xFFB73B2E), false),
                        _buildPaletteOption('Sabbia', const Color(0xFFD4B895), false),
                        _buildPaletteOption('Terra', const Color(0xFF1A1512), false),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Colori dinamici Material You',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                            ),
                            Text(
                              'Estrai tonalità dallo sfondo di sistema',
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _materialYou,
                          activeColor: primaryColor,
                          onChanged: (val) => setState(() => _materialYou = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- CARD 2: MAPPE & NAVIGAZIONE ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.map_outlined, color: primaryColor, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mappe & Navigazione',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Tracciamento percorsi e layer cartografici',
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unità di misura',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: mutedColor),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _unitSystem = 'km'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _unitSystem == 'km' ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Chilometri (km)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _unitSystem == 'km' ? Colors.white : textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _unitSystem = 'mi'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _unitSystem == 'mi' ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Miglia (mi)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _unitSystem == 'mi' ? Colors.white : textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Mappe offline
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_download_outlined, color: primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mappe offline locali',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                ),
                                Text(
                                  'Südtirol & Alpi (1.4 GB salvati)',
                                  style: TextStyle(fontSize: 12, color: mutedColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.sync, color: primaryColor),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sincronizzazione mappe offline completata')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stile visualizzazione mappa',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: mutedColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _mapSize = 'vettoriale'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _mapSize == 'vettoriale' ? primaryColor : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.map, color: _mapSize == 'vettoriale' ? primaryColor : mutedColor),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Vettoriale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                                      Text('Minimale e rapido', style: TextStyle(fontSize: 11, color: mutedColor)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _mapSize = '3d'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _mapSize == '3d' ? primaryColor : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.terrain, color: _mapSize == '3d' ? primaryColor : mutedColor),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Terreno 3D', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                                      Text('Curve di livello', style: TextStyle(fontSize: 11, color: mutedColor)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- CARD 3: ACCOUNT & SICUREZZA ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security_outlined, color: primaryColor, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account & Sicurezza',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Integrità crittografica e backup',
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Trattamento e privacy dati',
                      subtitle: 'Nessuna condivisione con terze parti',
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () {},
                    ),
                    const Divider(height: 24),
                    _buildSettingsTile(
                      icon: Icons.import_export,
                      title: 'Esporta conversazioni e waypoint',
                      subtitle: 'Archivio JSON e GPX compatibile',
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () {},
                    ),
                    const Divider(height: 24),
                    _buildSettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Backup crittografato end-to-end',
                      subtitle: 'Chiave memorizzata su hardware sicuro',
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pulsante Disconnetti Account
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account disconnesso')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF3A2020) : const Color(0xFFFFEEEE),
                    foregroundColor: Colors.red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Disconnetti account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Footer versione
              Center(
                child: Text(
                  'Aura OS v3.4.1 (Build 4192) • Progettato per te',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSegment(String label, IconData icon, bool isDark) {
    final isSelected = _themeMode == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _themeMode = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? AuraColors.textMutedDark : AuraColors.textMuted),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? AuraColors.textMainDark : AuraColors.textMain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteOption(String name, Color color, bool isSelected) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color mutedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, color: mutedColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: mutedColor),
        ],
      ),
    );
  }
}