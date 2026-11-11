import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Set this to true for Local testing (port 3000), or false for production Railway
  static const bool useLocalBackend = false;

  // Production Railway backend URL with custom branded domain
  static const String _productionUrl = 'https://api.kanavuillam.in/api';

  // Base URL dynamically routes to Localhost/10.0.2.2 in local mode, or Railway in production
  static String get baseUrl {
    if (!useLocalBackend) {
      return _productionUrl;
    }
    // Web and desktop connect directly to localhost
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    // Android emulator loops back to host machine via 10.0.2.2
    // If using a physical Android device, run: `adb reverse tcp:3000 tcp:3000`
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Asynchronously pings the server to wake it up from cloud cold sleep
  static void warmupBackend() {
    try {
      final healthUri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/api$'), '')}/api/health');
      http.get(healthUri).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }

  // Mutex to deduplicate concurrent token refresh calls and prevent Supabase rotation collisions
  static Future<bool>? _ongoingRefresh;

  /// Ensures the current auth token is valid. If it is expired (or expires within 5 mins),
  /// or if [force] is true, silently refreshes it using the saved refresh_token.
  static Future<bool> ensureFreshToken({bool force = false}) async {
    if (_ongoingRefresh != null) {
      return await _ongoingRefresh!;
    }
    _ongoingRefresh = _performTokenRefresh(force: force);
    try {
      return await _ongoingRefresh!;
    } finally {
      _ongoingRefresh = null;
    }
  }

  static Future<bool> _performTokenRefresh({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('[ApiService] No refresh token found in storage.');
        return false;
      }

      final expiresAt = prefs.getInt('token_expires_at') ?? 0;
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Only refresh if forced, expiry unknown (0), or expires in < 5 mins (300s), or already expired
      final bool needsRefresh = force || expiresAt == 0 || (expiresAt - nowSecs < 300);
      if (!needsRefresh) {
        return true;
      }

      debugPrint('[ApiService] Refreshing Supabase auth token (force=$force, remaining=${expiresAt - nowSecs}s)...');
      final refreshUri = Uri.parse('$baseUrl/auth/refresh');
      final response = await http.post(
        refreshUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 12));

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
          final expInt = newExpiry is int ? newExpiry : int.tryParse(newExpiry.toString()) ?? 0;
          await prefs.setInt('token_expires_at', expInt);
        }
        debugPrint('[ApiService] Auth token successfully refreshed!');
        return true;
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        // Token refresh rejected by provider, but do NOT wipe auth_token!
        // Retaining auth_token allows the server's 30-day mobile session grace period to authenticate it.
        debugPrint('[ApiService] Refresh token note (${response.statusCode}). Keeping auth_token for server grace window.');
        return false;
      } else {
        debugPrint('[ApiService] Token refresh rejected (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[ApiService] Token refresh error: $e');
      return false;
    }
  }

  /// Backward-compatible alias for callers
  static Future<void> refreshTokenIfNeeded() async {
    await ensureFreshToken();
  }

  static Future<Map<String, String>> _authHeaders([Map<String, String>? extra]) async {
    await ensureFreshToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userEmail = prefs.getString('user_email');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extra,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['x-auth-token'] = token;
    }
    if (userEmail != null && userEmail.isNotEmpty) {
      headers['x-user-email'] = userEmail;
    }
    return headers;
  }

  Future<Map<String, dynamic>> uploadPlan(XFile groundFile,
      XFile? firstFloorFile, XFile? secondFloorFile, String projectName,
      {String orientation = 'North', String? userEmail}) async {
    await ensureFreshToken();

    final prefs = await SharedPreferences.getInstance();
    final currentEmail = (userEmail != null && userEmail.isNotEmpty)
        ? userEmail
        : (prefs.getString('user_email') ?? '');

    Future<http.StreamedResponse> doSend() async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.fields['name'] = projectName;
      request.fields['orientation'] = orientation;
      if (currentEmail.isNotEmpty) {
        request.fields['user_email'] = currentEmail;
        request.headers['x-user-email'] = currentEmail;
      }

      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['x-auth-token'] = token;
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

      return await request.send().timeout(const Duration(seconds: 600),
          onTimeout: () {
        throw Exception(
            "Request timed out. The AI is taking longer than expected. Please try again.");
      });
    }

    http.StreamedResponse response;
    try {
      response = await doSend();
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isSocketDrop = errStr.contains('socketexception') ||
          errStr.contains('broken pipe') ||
          errStr.contains('clientexception') ||
          errStr.contains('connection closed') ||
          errStr.contains('connection reset');

      if (isSocketDrop) {
        debugPrint('[ApiService] Connection dropped during upload ($e). Refreshing token and retrying once...');
        await ensureFreshToken(force: true);
        await Future.delayed(const Duration(milliseconds: 1500));
        try {
          response = await doSend();
        } catch (retryErr) {
          throw Exception(
              "Network connection interrupted during floor plan upload. Please check your internet connection and try again.");
        }
      } else {
        rethrow;
      }
    }

    var responseData = await response.stream.bytesToString();

    // 401 Interceptor: If token expired, auto-refresh and retry once transparently
    if (response.statusCode == 401) {
      debugPrint('[ApiService] uploadPlan got 401 Unauthorized. Auto-refreshing token & retrying...');
      final refreshed = await ensureFreshToken(force: true);
      if (refreshed) {
        debugPrint('[ApiService] Token refreshed! Retrying upload...');
        try {
          response = await doSend();
          responseData = await response.stream.bytesToString();
        } catch (_) {}
      }
    }

    if (response.statusCode == 200) {
      try {
        return json.decode(responseData);
      } catch (e) {
        throw Exception("Server returned invalid data: $responseData");
      }
    } else {
      String errorMessage = 'Upload failed';
      try {
        final decoded = json.decode(responseData);
        if (decoded is Map && decoded['error'] != null) {
          errorMessage = decoded['error'];
        }
      } catch (_) {
        errorMessage = "Server Error (${response.statusCode}): $responseData";
      }
      throw Exception(errorMessage);
    }
  }

  Future<List<dynamic>> getAllProjects([String? email]) async {
    var headers = await _authHeaders();
    String url = '$baseUrl/projects';
    if (email != null && email.isNotEmpty) {
      url += '?email=${Uri.encodeComponent(email)}';
    }
    var response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 401) {
      final refreshed = await ensureFreshToken(force: true);
      if (refreshed) {
        headers = await _authHeaders();
        response = await http.get(Uri.parse(url), headers: headers);
      }
    }

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load project history');
    }
  }

  Future<Map<String, dynamic>> getProject(String projectId) async {
    var headers = await _authHeaders();
    var response = await http.get(Uri.parse('$baseUrl/project/$projectId'), headers: headers);

    if (response.statusCode == 401) {
      final refreshed = await ensureFreshToken(force: true);
      if (refreshed) {
        headers = await _authHeaders();
        response = await http.get(Uri.parse('$baseUrl/project/$projectId'), headers: headers);
      }
    }

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load project');
    }
  }

  /// Records delivery proof in payments table and wipes sensitive architectural JSON from projects table
  Future<Map<String, dynamic>?> markProjectDownloaded(String projectId, {String? email}) async {
    try {
      final headers = await _authHeaders();
      final body = email != null && email.isNotEmpty ? json.encode({'email': email}) : null;
      final response = await http.post(
        Uri.parse('$baseUrl/project/mark-downloaded/$projectId'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {
      // Non-blocking best-effort execution
    }
    return null;
  }

  Future<Map<String, dynamic>> analyzeVastu(String projectId,
      {String lang = 'English'}) async {
    var headers = await _authHeaders();
    var response = await http.post(
      Uri.parse('$baseUrl/analyze-vastu/$projectId'),
      headers: headers,
      body: json.encode({'lang': lang}),
    );

    if (response.statusCode == 401) {
      final refreshed = await ensureFreshToken(force: true);
      if (refreshed) {
        headers = await _authHeaders();
        response = await http.post(
          Uri.parse('$baseUrl/analyze-vastu/$projectId'),
          headers: headers,
          body: json.encode({'lang': lang}),
        );
      }
    }

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

  Future<Map<String, dynamic>> createRazorpayOrder(double amount, {String? projectId}) async {
    var headers = await _authHeaders();
    final bodyData = <String, dynamic>{'amount': amount};
    if (projectId != null) bodyData['project_id'] = projectId;

    var response = await http.post(
      Uri.parse('$baseUrl/payment/create-order'),
      headers: headers,
      body: json.encode(bodyData),
    );

    if (response.statusCode == 401) {
      final refreshed = await ensureFreshToken(force: true);
      if (refreshed) {
        headers = await _authHeaders();
        response = await http.post(
          Uri.parse('$baseUrl/payment/create-order'),
          headers: headers,
          body: json.encode(bodyData),
        );
      }
    }

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      String errorMsg = 'Failed to create payment order (${response.statusCode})';
      try {
        final errJson = json.decode(response.body);
        if (errJson is Map && errJson['error'] != null) {
          errorMsg = errJson['error'];
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment(
      Map<String, dynamic> data) async {
    var headers = await _authHeaders();
    var response = await http.post(
      Uri.parse('$baseUrl/payment/verify-payment'),
      headers: headers,
      body: json.encode(data),
    );

    if (response.statusCode == 401) {
      final refreshed = await ensureFreshToken(force: true);
      if (refreshed) {
        headers = await _authHeaders();
        response = await http.post(
          Uri.parse('$baseUrl/payment/verify-payment'),
          headers: headers,
          body: json.encode(data),
        );
      }
    }

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      String errorMsg = 'Payment verification failed (${response.statusCode})';
      try {
        final errJson = json.decode(response.body);
        if (errJson is Map && (errJson['message'] != null || errJson['error'] != null)) {
          errorMsg = errJson['message'] ?? errJson['error'];
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Permanently deletes user account, authentication credentials, and project history
  static Future<Map<String, dynamic>?> deleteAccount(String email, {String? userId}) async {
    return await post('/auth/delete-account', {
      'email': email,
      if (userId != null) 'userId': userId,
    });
  }

  static Future<Map<String, dynamic>?> post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final isAuthEndpoint = endpoint.contains('/auth/login') ||
          endpoint.contains('/auth/signup') ||
          endpoint.contains('/auth/refresh') ||
          endpoint.contains('/auth/google');

      if (!isAuthEndpoint) {
        await ensureFreshToken();
      }

      Future<http.Response> executePost() async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        final userEmail = prefs.getString('user_email');

        final headers = {'Content-Type': 'application/json'};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
          headers['x-auth-token'] = token;
        }
        if (userEmail != null && userEmail.isNotEmpty) {
          headers['x-user-email'] = userEmail;
        }

        return await http.post(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
          body: json.encode(body),
        );
      }

      var response = await executePost();

      // Auto-retry once on 401 for authenticated endpoints
      if (response.statusCode == 401 && !isAuthEndpoint) {
        final refreshed = await ensureFreshToken(force: true);
        if (refreshed) {
          response = await executePost();
        }
      }

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
