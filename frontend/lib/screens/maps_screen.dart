// lib/screens/maps_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../themes/app_colors.dart';
import 'add_marker_screen.dart';
import '../api/trash_api_service.dart';

/// Durata dello stato "pieno" (vale per cestini e singoli contenitori)
const Duration kFullDuration = Duration(hours: 12);

// ---------------------------------------------------------------------------
// CATALOGO DEI CONTENITORI
// Associa i materiali restituiti dal backend a titolo, colore, icona,
// elenco di cosa si può buttare e immagine.
//
// IMMAGINI: nel campo `image` puoi inserire
//   - un URL (https://...)  -> viene caricata da internet
//   - un asset (assets/bins/carta.png) -> dichiarato nel pubspec.yaml
// Se è vuoto (o non si carica) viene mostrata una grafica colorata con icona.
// ---------------------------------------------------------------------------
class _BinType {
  final List<String> keys; // parole chiave (minuscolo) cercate nel materiale
  final String title;
  final Color color;
  final IconData icon;
  final List<String> accepted;
  final String image;

  const _BinType({
    required this.keys,
    required this.title,
    required this.color,
    required this.icon,
    required this.accepted,
    this.image = '',
  });
}

const List<_BinType> _binTypes = [
  _BinType(
    keys: ['paper', 'carta', 'cardboard', 'cartone'],
    title: 'Carta e cartone',
    color: Color(0xFF1E88E5),
    icon: Icons.newspaper,
    accepted: [
      'Giornali e riviste',
      'Scatole di cartone piegate',
      'Fogli e quaderni',
      'Sacchetti di carta',
    ],
  ),
  _BinType(
    keys: ['glass', 'vetro'],
    title: 'Vetro',
    color: Color(0xFF43A047),
    icon: Icons.liquor,
    accepted: [
      'Bottiglie di vetro',
      'Barattoli e vasetti',
      'Bicchieri e caraffe',
    ],
  ),
  _BinType(
    keys: ['plastic', 'plastica'],
    title: 'Plastica',
    color: Color(0xFFF9A825),
    icon: Icons.local_drink_outlined,
    accepted: [
      'Bottiglie di plastica',
      'Flaconi di detersivi',
      'Vaschette e imballaggi puliti',
      'Sacchetti e pellicole',
    ],
  ),
  _BinType(
    keys: ['metal', 'metall', 'lattin', 'alumin'],
    title: 'Metalli e lattine',
    color: Color(0xFF78909C),
    icon: Icons.hardware_outlined,
    accepted: [
      'Lattine di bevande',
      'Scatolette di tonno e legumi',
      'Fogli di alluminio',
      'Tappi metallici',
    ],
  ),
  _BinType(
    keys: ['organ', 'umido', 'food'],
    title: 'Organico',
    color: Color(0xFF795548),
    icon: Icons.eco_outlined,
    accepted: [
      'Scarti di cucina',
      'Avanzi di cibo',
      'Filtri di tè e fondi di caffè',
      'Fiori e piante',
    ],
  ),
  _BinType(
    keys: ['cloth', 'abit', 'vestit', 'textile', 'tessil', 'shoes', 'scarpe'],
    title: 'Abiti usati',
    color: Color(0xFF8E24AA),
    icon: Icons.checkroom,
    accepted: [
      'Vestiti puliti',
      'Scarpe in coppia',
      'Borse e accessori',
      'Biancheria',
    ],
  ),
  _BinType(
    keys: ['batter', 'pile'],
    title: 'Pile esauste',
    color: Color(0xFFE53935),
    icon: Icons.battery_charging_full,
    accepted: [
      'Pile stilo e mini stilo',
      'Pile a bottone',
      'Batterie portatili piccole',
    ],
  ),
  _BinType(
    keys: ['oil', 'olio'],
    title: 'Olio esausto',
    color: Color(0xFFEF6C00),
    icon: Icons.opacity,
    accepted: [
      'Olio da cucina usato',
      'Olio di frittura',
    ],
  ),
  _BinType(
    keys: ['electr', 'raee', 'weee'],
    title: 'Elettronica (RAEE)',
    color: Color(0xFF3949AB),
    icon: Icons.devices_other,
    accepted: [
      'Piccoli elettrodomestici',
      'Cellulari e caricabatterie',
      'Cavi e accessori',
    ],
  ),
  _BinType(
    keys: ['medic', 'farmac', 'drug', 'pharm'],
    title: 'Medicinali',
    color: Color(0xFF2979FF),
    icon: Icons.local_pharmacy,
    accepted: [
      'Medicinali scaduti',
      'Compresse e sciroppi inutilizzati',
    ],
  ),
  _BinType(
    keys: ['residual', 'indifferenz', 'secco', 'general'],
    title: 'Indifferenziato',
    color: Color(0xFF757575),
    icon: Icons.delete_outline,
    accepted: [
      'Rifiuti non riciclabili',
      'Pannolini e assorbenti',
      'Cocci di ceramica',
      'Mozziconi e polvere',
    ],
  ),
];

class EcoBinItem {
  final String category;
  final List<String> accepted;
  final String imageUrl;
  final Color color;
  final IconData icon;

  /// Momento in cui il contenitore è stato segnalato pieno (null = non pieno)
  DateTime? fullSince;

  EcoBinItem({
    required this.category,
    required this.accepted,
    required this.imageUrl,
    required this.color,
    required this.icon,
    this.fullSince,
  });

  /// Crea il contenitore a partire dal materiale restituito dal backend
  factory EcoBinItem.fromMaterial(String material) {
    final m = material.toLowerCase().trim();
    for (final t in _binTypes) {
      if (t.keys.any((k) => m.contains(k))) {
        return EcoBinItem(
          category: t.title,
          accepted: t.accepted,
          imageUrl: t.image,
          color: t.color,
          icon: t.icon,
        );
      }
    }
    final label = m.isEmpty ? 'Altro' : m[0].toUpperCase() + m.substring(1);
    return EcoBinItem(
      category: label,
      accepted: const ['Controlla le indicazioni riportate sul contenitore.'],
      imageUrl: '',
      color: const Color(0xFF607D8B),
      icon: Icons.recycling,
    );
  }

  bool get isFull {
    final since = fullSince;
    if (since == null) return false;
    return DateTime.now().difference(since) < kFullDuration;
  }

  void markFull() => fullSince = DateTime.now();
  void markEmpty() => fullSince = null;
}

class EcoPoint {
  final String id;
  final String title;
  final String type; // 'disposal_center', 'island', 'bin', 'pharmacy'
  final LatLng location;
  final String description;
  final List<EcoBinItem> bins;

  /// Usato solo dai cestini: momento in cui è stato segnalato pieno
  DateTime? fullSince;

  EcoPoint({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.description,
    this.fullSince,
    this.bins = const [],
  });

  /// Cestino: pieno se la segnalazione ha meno di 12 ore.
  /// Isola ecologica: pieno solo se TUTTI i contenitori sono pieni.
  bool get isFull {
    if (type == 'island') {
      return bins.isNotEmpty && bins.every((b) => b.isFull);
    }
    final since = fullSince;
    if (since == null) return false;
    return DateTime.now().difference(since) < kFullDuration;
  }

  /// Numero di contenitori pieni (isole ecologiche)
  int get fullBinsCount => bins.where((b) => b.isFull).length;

  void markFull() => fullSince = DateTime.now();
  void markEmpty() => fullSince = null;
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

  Timer? _expiryTimer;

  // Punti caricati dal backend (GET /api/points)
  final List<EcoPoint> _ecoPoints = [];
  bool _loadingPoints = false;

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

    // Ridisegna ogni minuto per far scadere automaticamente lo stato "pieno"
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    _loadPoints(_initialCenter);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Mappa kind del backend -> tipo usato dalla UI
  static String _typeFromKind(String kind) {
    switch (kind) {
      case 'centre':
        return 'disposal_center';
      case 'pharmacy':
        return 'pharmacy';
      case 'bin':
      case 'waste_basket': // aggiungi qui eventuali altri nomi usati dal backend
        return 'bin';
      case 'container':
      default:
        return 'island';
    }
  }

  /// Trasforma i materiali del backend in contenitori (senza duplicati).
  /// Un cestino senza materiali indicati viene trattato come indifferenziato.
  static List<EcoBinItem> _binsFromMaterials(Iterable<dynamic> materials, String type) {
    final bins = <EcoBinItem>[];
    final seen = <String>{};
    for (final m in materials) {
      final bin = EcoBinItem.fromMaterial(m.toString());
      if (seen.add(bin.category)) bins.add(bin);
    }
    if (bins.isEmpty && type == 'bin') {
      bins.add(EcoBinItem.fromMaterial('indifferenziato'));
    }
    return bins;
  }

  Future<void> _loadPoints(LatLng center) async {
    setState(() => _loadingPoints = true);
    try {
      final points = await TrashApiService.getPoints(
        lat: center.latitude,
        lon: center.longitude,
        radiusM: 5000,
        limit: 200,
      );
      if (!mounted) return;

      // Conserva lo stato "pieno" dei punti e dei contenitori già noti
      final previousPointFull = {
        for (final p in _ecoPoints)
          if (p.fullSince != null) p.id: p.fullSince!,
      };
      final previousBinFull = {
        for (final p in _ecoPoints)
          for (final b in p.bins)
            if (b.fullSince != null) '${p.id}|${b.category}': b.fullSince!,
      };

      final newPoints = points.map((p) {
        final type = _typeFromKind(p.kind);
        final bins = _binsFromMaterials(p.materials, type);
        for (final b in bins) {
          b.fullSince = previousBinFull['${p.id}|${b.category}'];
        }
        return EcoPoint(
          id: p.id,
          title: p.name.isEmpty ? 'Punto di raccolta' : p.name,
          type: type,
          location: LatLng(p.lat, p.lon),
          description: [
            if (p.address != null) p.address!,
            if (p.openingHours != null) 'Orari: ${p.openingHours}',
          ].join('\n'),
          fullSince: previousPointFull[p.id],
          bins: bins,
        );
      }).toList();

      setState(() {
        _ecoPoints
          ..clear()
          ..addAll(newPoints);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loadingPoints = false);
    }
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
        'color': Colors.red.shade700,
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
      case 'pharmacy':
        return {
          'color': Colors.blueAccent, // Blu per le farmacie / raccolta medicinali
          'icon': Icons.local_pharmacy,
          'label': 'Raccolta Medicinali',
        };
      case 'bin':
        return {
          'color': Colors.grey.shade600, // Sfondo grigio
          'icon': Icons.delete_outline, // Icona del cestino
          'label': 'Cestino Pubblico',
        };
      case 'island':
      default:
        return {
          'color': isDark ? AuraColors.primaryGreenDark : AuraColors.primaryGreen, // Verde
          'icon': Icons.recycling,
          'label': 'Isola Ecologica',
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

  // ----- Stato pieno / vuoto: cestini (intero punto) -----
  void _setPointFull(EcoPoint point, StateSetter setModalState) {
    setState(() => point.markFull());
    setModalState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Segnalato come pieno (valido per 12 ore).'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _setPointEmpty(EcoPoint point, StateSetter setModalState) {
    setState(() => point.markEmpty());
    setModalState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Segnalato come vuoto.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ----- Stato pieno / vuoto: singolo contenitore di un'isola ecologica -----
  void _setBinFull(EcoBinItem bin, StateSetter setModalState) {
    setState(() => bin.markFull());
    setModalState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contenitore "${bin.category}" segnalato come pieno (valido per 12 ore).'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _setBinEmpty(EcoBinItem bin, StateSetter setModalState) {
    setState(() => bin.markEmpty());
    setModalState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contenitore "${bin.category}" segnalato come vuoto.'),
        duration: const Duration(seconds: 2),
      ),
    );
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
                    point.markFull();
                  } else {
                    _ecoPoints.removeWhere((p) => p.id == point.id);
                  }
                });

                Navigator.pop(context); // chiude il dialog
                Navigator.pop(context); // chiude il bottom sheet

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

  // ---------------------------------------------------------------------------
  // INTERFACCIA A BOX DEI CONTENITORI
  // ---------------------------------------------------------------------------

  /// Immagine del contenitore (URL, asset o grafica colorata di riserva)
  Widget _buildBinImage(EcoBinItem bin, double height) {
    Widget placeholder() => Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bin.color, bin.color.withOpacity(0.55)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -34,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
              ),
              Center(child: Icon(bin.icon, size: 58, color: Colors.white)),
            ],
          ),
        );

    final url = bin.imageUrl;
    if (url.isEmpty) return placeholder();

    if (url.startsWith('http')) {
      return Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    }
    return Image.asset(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder(),
    );
  }

  /// Box (stile Material 3 Expressive) di un singolo contenitore
  Widget _buildBinCard(
    EcoPoint point,
    EcoBinItem bin,
    bool isDark,
    StateSetter setModalState,
  ) {
    final textMain = isDark ? AuraColors.textMainDark : AuraColors.textMain;
    final textMuted = isDark ? AuraColors.textMutedDark : AuraColors.textMuted;
    final full = bin.isFull;
    final canToggle = point.type == 'island'; // solo le isole segnalano il singolo contenitore

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bin.color.withOpacity(isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: bin.color.withOpacity(0.30), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Immagine con eventuale badge "Pieno"
          Stack(
            children: [
              _buildBinImage(bin, 140),
              if (full)
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.45)),
                ),
              if (full)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'PIENO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bin.category,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'COSA PUOI BUTTARE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: bin.accepted
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: bin.color.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, size: 16, color: bin.color),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textMain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (canToggle) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => full
                          ? _setBinEmpty(bin, setModalState)
                          : _setBinFull(bin, setModalState),
                      style: FilledButton.styleFrom(
                        backgroundColor: (full ? Colors.green : Colors.orange).withOpacity(0.22),
                        foregroundColor: textMain,
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      icon: Icon(
                        full ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: full ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      label: Text(
                        full ? 'È vuoto' : 'Segnala pieno',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMarkerDetailsSheet(EcoPoint point) {
    setState(() {
      _selectedPoint = point;
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Calcolato qui dentro così si aggiorna appena cambia lo stato
            final style = _getMarkerStyle(point, isDark);

            // Il tasto "Segnala Pieno" a livello di punto esiste solo per i cestini.
            // Le isole ecologiche segnalano i singoli contenitori (nei box).
            final canReportFull = point.type == 'bin';

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

                    // --- SEZIONE BOX CONTENITORI: tipologie e cosa si può buttare ---
                    if (point.bins.isNotEmpty) ...[
                      Text(
                        point.type == 'bin' ? 'Cosa puoi buttare' : 'Contenitori e cosa puoi buttare',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AuraColors.textMainDark : AuraColors.textMain,
                        ),
                      ),
                      if (point.type == 'island') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Se un contenitore è pieno, segnalalo: lo stato dura 12 ore.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AuraColors.textMutedDark : AuraColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ...point.bins.map(
                        (bin) => _buildBinCard(point, bin, isDark, setModalState),
                      ),
                      const SizedBox(height: 4),
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
                          // Tasto "Segnala Pieno" / "È vuoto": solo per i cestini
                          if (canReportFull) ...[
                            TextButton.icon(
                              onPressed: () {
                                if (point.isFull) {
                                  _setPointEmpty(point, setModalState);
                                } else {
                                  _setPointFull(point, setModalState); // diretto, senza dialog
                                }
                              },
                              icon: Icon(
                                point.isFull ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                color: point.isFull ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              label: Text(
                                point.isFull ? 'È vuoto' : 'Segnala Pieno',
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
                          ],
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
      if (mounted) {
        setState(() {
          _selectedPoint = null;
        });
      }
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
      _loadPoints(currentLatLng);

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
          bins: result['type'] == 'bin'
              ? [EcoBinItem.fromMaterial('indifferenziato')]
              : [
                  EcoBinItem(
                    category: 'Generale',
                    accepted: const ['Conforme alla categoria del punto.'],
                    imageUrl:
                        'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=300&q=80',
                    color: const Color(0xFF00897B),
                    icon: Icons.recycling,
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

                    // Isola con alcuni (non tutti) contenitori pieni -> badge arancione
                    final partialFull = point.type == 'island' &&
                        !point.isFull &&
                        point.fullBinsCount > 0;

                    return Marker(
                      point: point.location,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetailsSheet(point),
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
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
                            if (partialFull)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Text(
                                    '${point.fullBinsCount}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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