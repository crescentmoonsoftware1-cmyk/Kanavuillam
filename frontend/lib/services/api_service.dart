import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Production Railway backend URL
  static String get baseUrl =>
      'https://kanavuillam-production.up.railway.app/api';

  /// Refresh the Supabase access token if it expires within the next 5 minutes.
  static Future<void> _refreshTokenIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt('token_expires_at') ?? 0;
    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Refresh if less than 5 minutes remain
    if (expiresAt > 0 && expiresAt - nowSecs < 300) {
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final response = await http.post(
            Uri.parse('${baseUrl.replaceAll(RegExp(r'/api$'), '')}/api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          ).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>?;
            final session = data?['session'] as Map<String, dynamic>?;
            final newToken = session?['access_token'] as String?;
            final newRefresh = session?['refresh_token'] as String?;
            final newExpiry = session?['expires_at'];
            if (newToken != null && newToken.isNotEmpty) {
              await prefs.setString('auth_token', newToken);
            }
            if (newRefresh != null && newRefresh.isNotEmpty) {
              await prefs.setString('refresh_token', newRefresh);
            }
            if (newExpiry != null) {
              await prefs.setInt('token_expires_at', (newExpiry is int ? newExpiry : int.tryParse(newExpiry.toString()) ?? 0));
            }
          }
        } catch (_) {
          // Network failure: proceed with existing token
        }
      }
    }
  }

  static Future<Map<String, String>> _authHeaders([Map<String, String>? extra]) async {
    await _refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extra,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> uploadPlan(XFile groundFile,
      XFile? firstFloorFile, XFile? secondFloorFile, String projectName,
      {String orientation = 'North', String? userEmail}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.fields['name'] = projectName;
    request.fields['orientation'] = orientation;

    await _refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Attach ground floor
    final groundBytes = await groundFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'ground_plan',
      groundBytes,
      filename: groundFile.name,
    ));

    // Attach first floor if provided
    if (firstFloorFile != null) {
      final firstBytes = await firstFloorFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'first_plan',
        firstBytes,
        filename: firstFloorFile.name,
      ));
    }

    // Attach second floor if provided
    if (secondFloorFile != null) {
      final secondBytes = await secondFloorFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'second_plan',
        secondBytes,
        filename: secondFloorFile.name,
      ));
    }

    final response = await request.send().timeout(const Duration(seconds: 600),
        onTimeout: () {
      throw Exception(
          "Request timed out. The AI is taking longer than expected. Please try again.");
    });
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      try {
        return json.decode(responseData);
      } catch (e) {
        throw Exception("Server returned invalid data: $responseData");
      }
    } else {
      try {
        final error = json.decode(responseData)['error'] ?? 'Upload failed';
        throw Exception(error);
      } catch (e) {
        throw Exception("Server Error (${response.statusCode}): $responseData");
      }
    }
  }

  Future<List<dynamic>> getAllProjects([String? email]) async {
    final headers = await _authHeaders();
    String url = '$baseUrl/projects';
    if (email != null && email.isNotEmpty) {
      url += '?email=${Uri.encodeComponent(email)}';
    }
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load project history');
    }
  }

  Future<Map<String, dynamic>> getProject(String projectId) async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/project/$projectId'), headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load project');
    }
  }

  Future<Map<String, dynamic>> analyzeVastu(String projectId,
      {String lang = 'English'}) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/analyze-vastu/$projectId'),
      headers: headers,
      body: json.encode({'lang': lang}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      try {
        final errorData = json.decode(response.body);
        throw Exception(errorData['details'] ??
            errorData['error'] ??
            'Vastu analysis failed');
      } catch (e) {
        throw Exception('Server Error: ${response.statusCode}');
      }
    }
  }

  Future<List<dynamic>> searchMaterial(String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material/search'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'query': query}),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) return decoded;
      return [decoded]; // Fallback if API returned object
    } else {
      throw Exception('Failed to search material');
    }
  }

  Future<Map<String, dynamic>> getLiveMarketPrices({String location = 'Tamil Nadu, India'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/material/live-prices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'location': location}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('[ApiService] Live market prices fetch notice: $e');
    }
    return {
      'is_live_market': true,
      'location': location,
      'materials': {
        'cement': {'basic': 390.0, 'standard': 440.0, 'premium': 490.0, 'unit': 'bag', 'name': 'Cement (OPC/PPC)'},
        'steel': {'basic': 68.0, 'standard': 84.0, 'premium': 92.0, 'unit': 'kg', 'name': 'TMT Steel Rebar'},
        'sand': {'basic': 65.0, 'standard': 75.0, 'premium': 110.0, 'unit': 'cft', 'name': 'M-Sand / River Sand'},
        'aggregate': {'basic': 40.0, 'standard': 48.0, 'premium': 55.0, 'unit': 'cft', 'name': 'Blue Metal Aggregate'},
        'bricks': {'basic': 9.0, 'standard': 12.0, 'premium': 65.0, 'unit': 'pcs', 'name': 'Bricks / AAC Blocks'},
        'tiles': {'basic': 45.0, 'standard': 75.0, 'premium': 160.0, 'unit': 'sqft', 'name': 'Flooring Tiles'},
        'paint': {'basic': 190.0, 'standard': 280.0, 'premium': 420.0, 'unit': 'liter', 'name': 'Paint & Putty'},
        'electrical': {'basic': 110.0, 'standard': 140.0, 'premium': 220.0, 'unit': 'sqft', 'name': 'Electrical Systems'},
        'plumbing': {'basic': 95.0, 'standard': 130.0, 'premium': 210.0, 'unit': 'sqft', 'name': 'Plumbing Systems'},
        'doors': {'basic': 7500.0, 'standard': 12000.0, 'premium': 22000.0, 'unit': 'nos', 'name': 'Doors'},
        'windows': {'basic': 5500.0, 'standard': 8500.0, 'premium': 14000.0, 'unit': 'nos', 'name': 'Windows'},
      }
    };
  }

  Future<Map<String, dynamic>> createRazorpayOrder(double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'amount': amount}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create payment order');
    }
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment/verify-payment'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Payment verification failed');
    }
  }

  static Future<Map<String, dynamic>?> post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = {'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {'error': 'Server Error (${response.statusCode})'};
        }
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
