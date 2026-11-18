// lib/services/trash_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ==================== MODELLI DATI ====================

class HealthModel {
  final String status;
  final String municipality;
  final int pointsCount;

  HealthModel({
    required this.status,
    required this.municipality,
    required this.pointsCount,
  });

  factory HealthModel.fromJson(Map<String, dynamic> json) {
    return HealthModel(
      status: json['status'] ?? '',
      municipality: json['municipality'] ?? '',
      pointsCount: json['points_count'] ?? 0,
    );
  }
}

class NoteModel {
  final String id;
  final String text;
  final String? ref;

  NoteModel({required this.id, required this.text, this.ref});

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      ref: json['ref'],
    );
  }
}

class InfoModel {
  final String municipality;
  final String source;
  final String mapAttribution;
  final List<NoteModel> notes;

  InfoModel({
    required this.municipality,
    required this.source,
    required this.mapAttribution,
    required this.notes,
  });

  factory InfoModel.fromJson(Map<String, dynamic> json) {
    return InfoModel(
      municipality: json['municipality'] ?? '',
      source: json['source'] ?? '',
      mapAttribution: json['map_attribution'] ?? '',
      notes: (json['notes'] as List?)?.map((n) => NoteModel.fromJson(n)).toList() ?? [],
    );
  }
}

class CategoryModel {
  final String id;
  final String name;
  final String bin;
  final String color;
  final String instructions;
  final bool hasPoints;
  final String? ref;

  CategoryModel({
    required this.id,
    required this.name,
    required this.bin,
    required this.color,
    required this.instructions,
    required this.hasPoints,
    this.ref,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      bin: json['bin'] ?? '',
      color: json['color'] ?? '#000000',
      instructions: json['instructions'] ?? '',
      hasPoints: json['has_points'] ?? true,
      ref: json['ref'],
    );
  }
}

class PointModel {
  final String id;
  final double lat;
  final double lon;
  final String kind;
  final String name;
  final List<String> materials;
  final String? openingHours;
  final String? address;
  final int? distanceM;

  PointModel({
    required this.id,
    required this.lat,
    required this.lon,
    required this.kind,
    required this.name,
    required this.materials,
    this.openingHours,
    this.address,
    this.distanceM,
  });

  factory PointModel.fromJson(Map<String, dynamic> json) {
    return PointModel(
      id: json['id'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      kind: json['kind'] ?? '',
      name: json['name'] ?? '',
      materials: List<String>.from(json['materials'] ?? []),
      openingHours: json['opening_hours'],
      address: json['address'],
      distanceM: json['distance_m'],
    );
  }
}

class AskResponseModel {
  final String lang;
  final bool found;
  final String source;
  final String? item;
  final CategoryModel? category;
  final String answer;
  final List<PointModel>? points;

  AskResponseModel({
    required this.lang,
    required this.found,
    required this.source,
    this.item,
    this.category,
    required this.answer,
    this.points,
  });

  factory AskResponseModel.fromJson(Map<String, dynamic> json) {
    return AskResponseModel(
      lang: json['lang'] ?? 'it',
      found: json['found'] ?? false,
      source: json['source'] ?? 'ai',
      item: json['item'],
      category: json['category'] != null ? CategoryModel.fromJson(json['category']) : null,
      answer: json['answer'] ?? '',
      points: json['points'] != null
          ? (json['points'] as List).map((p) => PointModel.fromJson(p)).toList()
          : null,
    );
  }
}

// ==================== SERVIZIO API ====================

class TrashApiService {
  // Di default il backend sul Raspberry (Cloudflare Tunnel).
  // Per usare il backend sul PC:  flutter run --dart-define=API_URL=local
  static const String _apiUrl =
      String.fromEnvironment('API_URL', defaultValue: 'https://trashy.natsu-cloud.fyi');

  static String get baseUrl {
    if (_apiUrl != 'local') return _apiUrl;
    // Backend locale: l'emulatore Android vede il PC come 10.0.2.2
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  // --- GET /api/health[cite: 3] ---
  static Future<HealthModel> checkHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/api/health'));
    if (response.statusCode == 200) {
      return HealthModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Errore nel controllo dello stato del server');
  }

  // --- GET /api/info[cite: 3, 4] ---
  static Future<InfoModel> getInfo({String lang = 'it'}) async {
    final response = await http.get(Uri.parse('$baseUrl/api/info?lang=$lang'));
    if (response.statusCode == 200) {
      return InfoModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Errore nel recupero delle informazioni');
  }

  // --- GET /api/categories[cite: 3, 5] ---
  static Future<List<CategoryModel>> getCategories({String lang = 'it'}) async {
    final response = await http.get(Uri.parse('$baseUrl/api/categories?lang=$lang'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    }
    throw Exception('Errore nel recupero delle categorie');
  }

  // --- GET /api/categories/{category_id}[cite: 3, 6] ---
  static Future<CategoryModel> getCategoryDetail(String categoryId, {String lang = 'it'}) async {
    final response = await http.get(Uri.parse('$baseUrl/api/categories/$categoryId?lang=$lang'));
    if (response.statusCode == 200) {
      return CategoryModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      throw Exception('Categoria non trovata');
    }
    throw Exception('Errore di rete');
  }

  // --- POST /api/ask[cite: 3, 7] ---
  static Future<AskResponseModel> askAssistant({
    required String text,
    String? lang,
    double? lat,
    double? lon,
    int? radiusM,
  }) async {
    final url = Uri.parse('$baseUrl/api/ask');
    
    final Map<String, dynamic> bodyData = {'text': text};
    if (lang != null) bodyData['lang'] = lang;
    if (lat != null && lon != null) {
      bodyData['lat'] = lat;
      bodyData['lon'] = lon;
    }
    if (radiusM != null) bodyData['radius_m'] = radiusM;

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyData),
    );

    if (response.statusCode == 200) {
      return AskResponseModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 429) {
      throw Exception('Troppe richieste (Rate limit superato). Riprova tra poco.');
    } else if (response.statusCode == 422) {
      throw Exception('Dati di input non validi.');
    }
    throw Exception('Errore del server: ${response.statusCode}');
  }

  // --- GET /api/points[cite: 3, 8] ---
  static Future<List<PointModel>> getPoints({
    required double lat,
    required double lon,
    int radiusM = 3000,
    String? category,
    String? kind,
    int limit = 20,
  }) async {
    final queryParameters = {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius_m': radiusM.toString(),
      'limit': limit.toString(),
      if (category != null) 'category': category,
      if (kind != null) 'kind': kind,
    };

    final uri = Uri.parse('$baseUrl/api/points').replace(queryParameters: queryParameters);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => PointModel.fromJson(json)).toList();
    } else if (response.statusCode == 404) {
      throw Exception('La categoria specificata non esiste');
    }
    throw Exception('Errore nel recupero dei punti di raccolta');
  }
}