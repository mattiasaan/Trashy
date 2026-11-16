// lib/screens/maps_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../themes/app_colors.dart';
import 'add_marker_screen.dart';

class EcoPoint {
  final String id;
  final String title;
  final String type; // 'island', 'bell', 'bin'
  final LatLng location;
  final String description;

  EcoPoint({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.description,
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

  final List<EcoPoint> _ecoPoints = [
    EcoPoint(
      id: '1',
      title: 'Isola Ecologica Centrale',
      type: 'island',
      location: const LatLng(46.4990, 11.3560),
      description: 'Raccolta differenziata completa, ingombranti e RAEE.',
    ),
    EcoPoint(
      id: '2',
      title: 'Campana Vetro & Carta',
      type: 'bell',
      location: const LatLng(46.4965, 11.3520),
      description: 'Campana dedicata esclusivamente a vetro e carta.',
    ),
    EcoPoint(
      id: '3',
      title: 'Cestino Pubblico Smart',
      type: 'bin',
      location: const LatLng(46.5005, 11.3535),
      description: 'Cestino urbano per rifiuti indifferenziati.',
    ),
    EcoPoint(
      id: '4',
      title: 'Isola Ecologica Quartiere',
      type: 'island',
      location: const LatLng(46.4950, 11.3580),
      description: 'Punto di raccolta di quartiere aperto H24.',
    ),
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

  Map<String, dynamic> _getMarkerStyle(String type, bool isDark) {
    switch (type) {
      case 'island':
        return {
          'color': isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen,
          'icon': Icons.recycling,
          'label': 'Isola Ecologica',
        };
      case 'bell':
        return {
          'color': Colors.blueAccent,
          'icon': Icons.wine_bar,
          'label': 'Campana (Vetro/Carta)',
        };
      case 'bin':
      default:
        return {
          'color': isDark ? AuraColors.accentCottoDark : AuraColors.accentCotto,
          'icon': Icons.delete_outline,
          'label': 'Cestino Pubblico',
        };
    }
  }

  // Funzione per lanciare Google Maps esterno per le indicazioni stradali
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

  // Mostra il pannello dettagliato dal basso al click sul marker
  void _showMarkerDetailsSheet(EcoPoint point) {
    setState(() {
      _selectedPoint = point;
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _getMarkerStyle(point.type, isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
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
                'Descrizione e dettagli:',
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
              const SizedBox(height: 24),
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
          type: result['type'],
          location: result['location'],
          description: result['description'],
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
                  ..._filteredPoints.map((point) {
                    final style = _getMarkerStyle(point.type, isDark);
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

          // Search bar e filtri superiori
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
                        hintText: 'Cerca isole, campane o cestini...',
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
                        _buildFilterChip('Isole Ecologiche', 'island', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Campane', 'bell', isDark),
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