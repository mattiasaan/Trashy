// lib/screens/maps_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../themes/app_colors.dart';
import 'add_marker_screen.dart';

class EcoBinItem {
  final String category; 
  final String allowedItems;
  final String imageUrl;

  EcoBinItem({
    required this.category,
    required this.allowedItems,
    required this.imageUrl,
  });
}

class EcoPoint {
  final String id;
  final String title;
  final String type; // 'disposal_center', 'island', 'bin', 'pharmacy'
  final LatLng location;
  final String description;
  bool isFull;
  final List<EcoBinItem> bins;

  EcoPoint({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.description,
    this.isFull = false,
    this.bins = const [],
  });
}

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  final LatLng _initialCenter = const LatLng(46.4983, 11.3548);
  
  String _selectedFilter = 'all';
  String _searchQuery = '';
  EcoPoint? _selectedPoint;
  
  LatLng? _currentPosition;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Lista iniziale con Centro di smaltimento, Isole ecologiche, Cestini e Farmacia (Raccolta Medicinali)
  final List<EcoPoint> _ecoPoints = [
    // 1 Centro di Smaltimento principale
    EcoPoint(
      id: 'disp_1',
      title: 'Centro di Smaltimento Principale',
      type: 'disposal_center',
      location: const LatLng(46.4990, 11.3560),
      description: 'Centro di raccolta comunale per tutti i tipi di materiali e rifiuti ingombranti.',
      bins: [
        EcoBinItem(
          category: 'Campana del Vetro',
          allowedItems: 'Bottiglie, vasetti e barattoli di vetro.',
          imageUrl: 'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?auto=format&fit=crop&w=300&q=80',
        ),
        EcoBinItem(
          category: 'Campana della Carta',
          allowedItems: 'Giornali, riviste, cartoni piegati.',
          imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=300&q=80',
        ),
      ],
    ),

    // 3 Isole Ecologiche
    EcoPoint(
      id: 'island_1',
      title: 'Isola Ecologica Quartiere Nord',
      type: 'island',
      location: const LatLng(46.5020, 11.3510),
      description: 'Isola ecologica di zona per la differenziata di base.',
      bins: [
        EcoBinItem(
          category: 'Campana del Vetro',
          allowedItems: 'Bottiglie e barattoli in vetro.',
          imageUrl: 'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?auto=format&fit=crop&w=300&q=80',
        ),
      ],
    ),
    EcoPoint(
      id: 'island_2',
      title: 'Isola Ecologica Centro',
      type: 'island',
      location: const LatLng(46.4965, 11.3520),
      description: 'Isola ecologica di zona aperta H24.',
      bins: [
        EcoBinItem(
          category: 'Campana della Carta',
          allowedItems: 'Carta e cartone.',
          imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=300&q=80',
        ),
      ],
    ),
    EcoPoint(
      id: 'island_3',
      title: 'Isola Ecologica Sud',
      type: 'island',
      location: const LatLng(46.4940, 11.3590),
      description: 'Punto di raccolta multimateriale.',
      bins: [
        EcoBinItem(
          category: 'Campana della Plastica',
          allowedItems: 'Imballaggi in plastica.',
          imageUrl: 'https://images.unsplash.com/photo-1611284416318-3905eca149d3?auto=format&fit=crop&w=300&q=80',
        ),
      ],
    ),

    // 1 Punto di raccolta medicinali (Farmacia)
    EcoPoint(
      id: 'pharmacy_1',
      title: 'Farmacia Comunale - Raccolta Medicinali',
      type: 'pharmacy',
      location: const LatLng(46.4975, 11.3540),
      description: 'Contenitore dedicato allo smaltimento sicuro di medicinali scaduti o scarti di farmaci.',
      bins: [
        EcoBinItem(
          category: 'Contenitore Farmaci Scaduti',
          allowedItems: 'Compresse, sciroppi, flaconi e pomate scaduti (senza scatola di cartone esterna).',
          imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=300&q=80',
        ),
      ],
    ),

    // 10 Cestini Pubblici
    EcoPoint(id: 'bin_1', title: 'Cestino Via Roma 1', type: 'bin', location: const LatLng(46.4980, 11.3530), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_2', title: 'Cestino Via Roma 12', type: 'bin', location: const LatLng(46.4983, 11.3535), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_3', title: 'Cestino Piazza Walther', type: 'bin', location: const LatLng(46.4995, 11.3542), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_4', title: 'Cestino Via Portici', type: 'bin', location: const LatLng(46.4970, 11.3548), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_5', title: 'Cestino Via Museo', type: 'bin', location: const LatLng(46.5001, 11.3520), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_6', title: 'Cestino Lungo Talvera', type: 'bin', location: const LatLng(46.5015, 11.3530), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_7', title: 'Cestino Via Cappuccini', type: 'bin', location: const LatLng(46.4950, 11.3560), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_8', title: 'Cestino Viale Trento', type: 'bin', location: const LatLng(46.4935, 11.3525), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_9', title: 'Cestino Via Torino', type: 'bin', location: const LatLng(46.4915, 11.3540), description: 'Cestino urbano.'),
    EcoPoint(id: 'bin_10', title: 'Cestino Corso Italia', type: 'bin', location: const LatLng(46.4955, 11.3485), description: 'Cestino urbano.'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 20.0, end: 50.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<EcoPoint> get _filteredPoints {
    return _ecoPoints.where((point) {
      final matchesFilter = _selectedFilter == 'all' || point.type == _selectedFilter;
      final matchesSearch = point.title.toLowerCase().contains(_searchQuery) ||
          point.description.toLowerCase().contains(_searchQuery);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  // Configurazione dei colori e icone per le categorie supportate
  Map<String, dynamic> _getMarkerStyle(EcoPoint point, bool isDark) {
    if (point.isFull) {
      return {
        'color': Colors.grey.shade700,
        'icon': Icons.block,
        'label': 'Punto Pieno / Colmo',
      };
    }

    switch (point.type) {
      case 'disposal_center':
        return {
          'color': const Color(0xFF795548), // Marrone
          'icon': Icons.recycling,
          'label': 'Centro di Smaltimento',
        };
      case 'island':
        return {
          'color': isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen, // Verde
          'icon': Icons.recycling,
          'label': 'Isola Ecologica',
        };
      case 'pharmacy':
        return {
          'color': Colors.blueAccent, // Blu per le farmacie / raccolta medicinali
          'icon': Icons.local_pharmacy,
          'label': 'Raccolta Medicinali',
        };
      case 'bin':
      default:
        return {
          'color': Colors.grey, // Grigio
          'icon': Icons.delete_outline,
          'label': 'Cestino Pubblico',
        };
    }
  }

  Future<void> _openGoogleMaps(LatLng location, String title) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire Google Maps')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nell\'apertura della mappa: $e')),
      );
    }
  }

  void _showReportDialog(EcoPoint point, bool isFullReport) {
    final TextEditingController reportTitleController = TextEditingController(
      text: isFullReport ? 'Segnalazione contenitore pieno' : 'Segnalazione rimozione punto',
    );
    final TextEditingController reportDescController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AuraColors.darkCard : AuraColors.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isFullReport ? 'Argomenta Segnalazione Pieno' : 'Argomenta Inesistenza',
            style: TextStyle(color: isDark ? AuraColors.textMainDark : AuraColors.textMain, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reportTitleController,
                  style: TextStyle(color: isDark ? AuraColors.textMainDark : AuraColors.textMain),
                  decoration: InputDecoration(
                    labelText: 'Titolo segnalazione',
                    labelStyle: TextStyle(color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted),
                    filled: true,
                    fillColor: isDark ? AuraColors.darkBg : AuraColors.lightBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reportDescController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? AuraColors.textMainDark : AuraColors.textMain),
                  decoration: InputDecoration(
                    labelText: 'Aggiungi una descrizione...',
                    labelStyle: TextStyle(color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted),
                    filled: true,
                    fillColor: isDark ? AuraColors.darkBg : AuraColors.lightBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla', style: TextStyle(color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (isFullReport) {
                    point.isFull = true;
                  } else {
                    _ecoPoints.removeWhere((p) => p.id == point.id);
                  }
                });

                Navigator.pop(context);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFullReport
                          ? 'Segnalazione inviata: punto contrassegnato come pieno!'
                          : 'Segnalazione registrata: punto rimosso.',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isFullReport ? Colors.orange : Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Invia Segnalazione', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showMarkerDetailsSheet(EcoPoint point) {
    setState(() {
      _selectedPoint = point;
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _getMarkerStyle(point, isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: style['color'].withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            style['icon'],
                            color: style['color'],
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                point.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: style['color'].withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  style['label'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: style['color'],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(color: isDark ? AuraColors.darkSurface : AuraColors.lightSurface),
                    const SizedBox(height: 12),
                    Text(
                      'Descrizione generale:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      point.description,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- SEZIONE BOX CASSONETTI / CAMPANE DELL'AREA ---
                    if (point.bins.isNotEmpty) ...[
                      Text(
                        'Tipologie di Cassonetti e Campane:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...point.bins.map((bin) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AuraColors.darkBg : AuraColors.lightBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                bin.imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey.withOpacity(0.3),
                                  child: const Icon(Icons.image_not_supported, size: 30),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bin.category,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cosa conferire: ${bin.allowedItems}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 10),
                    ],

                    // Sezione Segnalazioni
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AuraColors.darkBg : AuraColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showReportDialog(point, true),
                            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            label: Text(
                              'Segnala Pieno',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted,
                          ),
                          TextButton.icon(
                            onPressed: () => _showReportDialog(point, false),
                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                            label: Text(
                              'Non esiste',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openGoogleMaps(point.location, point.title);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: style['color'],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.directions, color: Colors.white),
                        label: const Text(
                          'Ottieni Indicazioni (Maps)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        _selectedPoint = null;
      });
    });
  }

  Future<void> _recenterToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('I servizi di geolocalizzazione sono disattivati.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('I permessi di posizione sono stati negati.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('I permessi di posizione sono permanentemente negati.')),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentPosition = currentLatLng;
      });

      _mapController.move(currentLatLng, 16.0);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Posizione attuale rilevata!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel recupero della posizione: $e')),
      );
    }
  }

  Future<void> _addNewMarker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMarkerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        final newPoint = EcoPoint(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: result['title'],
          type: result['type'], // 'disposal_center', 'island', 'bin', o 'pharmacy'
          location: result['location'],
          description: result['description'],
          bins: [
            EcoBinItem(
              category: 'Generale',
              allowedItems: 'Conforme alla categoria del punto.',
              imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=300&q=80',
            ),
          ],
        );
        _ecoPoints.add(newPoint);
        _mapController.move(newPoint.location, 16.0);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marker aggiunto con successo!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen;
    final mutedColor = isDark ? AuraColors.textMutedDark : AuraColors.textMuted;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15.0,
              onTap: (_, __) => setState(() => _selectedPoint = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.frontend',
              ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final size = _pulseAnimation.value.clamp(10.0, 60.0);
                          return Center(
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: size,
                                    height: size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.withOpacity(0.3),
                                    ),
                                  ),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Rendering pulito dei marker principali
                  ..._filteredPoints.map((point) {
                    final style = _getMarkerStyle(point, isDark);
                    final isSelected = _selectedPoint?.id == point.id;

                    return Marker(
                      point: point.location,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetailsSheet(point),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: style['color'],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            style['icon'],
                            color: Colors.white,
                            size: isSelected ? 26 : 22,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Search bar e filtri superiori aggiornati
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cerca centri, isole, farmacie o cestini...',
                        hintStyle: TextStyle(color: mutedColor),
                        icon: Icon(Icons.search, color: mutedColor),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tutti', 'all', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Centro Smaltimento', 'disposal_center', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Isole Ecologiche', 'island', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Farmacie (Medicinali)', 'pharmacy', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Cestini', 'bin', isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pulsanti fluttuanti in basso a destra
          Positioned(
            right: 16,
            bottom: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'addMarkerBtn',
                  onPressed: _addNewMarker,
                  backgroundColor: primaryColor,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'gpsBtn',
                  onPressed: _recenterToCurrentLocation,
                  backgroundColor: isDark ? AuraColors.darkCard : AuraColors.lightCard,
                  child: Icon(
                    Icons.my_location,
                    color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    final primaryColor = isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? AuraColors.darkCard : AuraColors.lightCard),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AuraColors.textMainDark : AuraColors.textMain),
          ),
        ),
      ),
    );
  }
}