// lib/screens/add_marker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../themes/app_colors.dart';

class AddMarkerScreen extends StatefulWidget {
  const AddMarkerScreen({super.key});

  @override
  State<AddMarkerScreen> createState() => _AddMarkerScreenState();
}

class _AddMarkerScreenState extends State<AddMarkerScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  // Categoria di default: Isola ecologica
  String _selectedCategory = 'island';
  
  // Posizione selezionata sulla mappa (iniziale di fallback es. Bolzano)
  LatLng _selectedLocation = const LatLng(46.4983, 11.3548);
  final MapController _mapController = MapController();

  final Map<String, String> _categories = {
    'island': 'Isola Ecologica',
    'bell': 'Campana (Vetro/Carta)',
    'bin': 'Cestino Pubblico',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _saveMarker() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo per il marker')),
      );
      return;
    }

    // Creiamo il nuovo punto da restituire alla schermata precedente
    final newEcoPoint = {
      'title': title,
      'type': _selectedCategory,
      'location': _selectedLocation,
      'description': _descriptionController.text.trim().isEmpty 
          ? 'Nessuna descrizione' 
          : _descriptionController.text.trim(),
    };

    // Chiude la schermata e restituisce i dati
    Navigator.pop(context, newEcoPoint);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen;

    return Scaffold(
      backgroundColor: isDark ? AuraColors.darkBg : AuraColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Aggiungi Nuovo Punto',
          style: TextStyle(
            color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campo Titolo
            TextField(
              controller: _titleController,
              style: TextStyle(color: isDark ? AuraColors.textMainDark : AuraColors.textMain),
              decoration: InputDecoration(
                labelText: 'Titolo del punto',
                labelStyle: TextStyle(color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted),
                filled: true,
                fillColor: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown Categoria
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                  isExpanded: true,
                  items: _categories.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Campo Descrizione
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: TextStyle(color: isDark ? AuraColors.textMainDark : AuraColors.textMain),
              decoration: InputDecoration(
                labelText: 'Descrizione (opzionale)',
                labelStyle: TextStyle(color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted),
                filled: true,
                fillColor: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Selezione Posizione su Mappa
            Text(
              'Tocca la mappa per posizionare il marker:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
              ),
            ),
            const SizedBox(height: 10),
            
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 250,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _selectedLocation = latLng;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.frontend',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Pulsante di Conferma
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveMarker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Salva e Aggiungi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
