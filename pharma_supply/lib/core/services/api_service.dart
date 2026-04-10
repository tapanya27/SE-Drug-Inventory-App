import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';
  static String? _token;
  static String? _refreshToken;
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs?.getString('access_token');
    _refreshToken = _prefs?.getString('refresh_token');
  }

  static String? get token => _token;
  static String? get userRole => _prefs?.getString('user_role');
  static bool get isVerified => _prefs?.getBool('is_verified') ?? false;

  static Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    await _prefs?.clear();
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    var response = await requestFn();

    if (response.statusCode == 401 && _refreshToken != null) {
      // Try to refresh
      final refreshSuccess = await _tryRefreshToken();
      if (refreshSuccess) {
        // Retry once
        response = await requestFn();
      }
    }
    return response;
  }

  static Future<bool> _tryRefreshToken() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        await _prefs?.setString('access_token', _token!);
        return true;
      }
    } catch (_) {}
    
    // If refresh fails, log out
    await logout();
    return false;
  }

  // --- Auth ---
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['access_token'];
      _refreshToken = data['refresh_token'];
      
      await _prefs?.setString('access_token', _token!);
      await _prefs?.setString('refresh_token', _refreshToken!);
      await _prefs?.setString('user_role', data['role']);
      await _prefs?.setString('user_email', email);
      await _prefs?.setBool('is_verified', data['is_verified'] ?? false);
      
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Login failed');
    }
  }

  static Future<void> signup(String name, String email, String password, String role) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Signup failed');
    }
  }

  // --- Inventory ---
  static Future<List<dynamic>> getInventory() async {
    final response = await _authenticatedRequest(
      () => http.get(Uri.parse('$baseUrl/inventory'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load inventory (${response.statusCode})');
    }
  }

  static Future<List<dynamic>> getCatalog() async {
    final response = await _authenticatedRequest(
      () => http.get(Uri.parse('$baseUrl/inventory/catalog'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load catalog (${response.statusCode})');
    }
  }

  static Future<void> addToInventory(int medicineId) async {
    final response = await _authenticatedRequest(
      () => http.post(
        Uri.parse('$baseUrl/inventory/add/$medicineId'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add product to inventory (${response.statusCode})');
    }
  }

  static Future<List<dynamic>> getLowStockAlerts() async {
    final response = await _authenticatedRequest(
      () => http.get(Uri.parse('$baseUrl/inventory/low-stock'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load critical alerts (${response.statusCode})');
    }
  }

  // --- Orders ---
  static Future<void> placeOrder(List<Map<String, dynamic>> items) async {
    final response = await _authenticatedRequest(
      () => http.post(
        Uri.parse('$baseUrl/orders'),
        headers: _headers,
        body: jsonEncode({'items': items}),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to place order (${response.statusCode})');
    }
  }

  static Future<List<dynamic>> getOrders() async {
    final response = await _authenticatedRequest(
      () => http.get(Uri.parse('$baseUrl/orders'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load orders (${response.statusCode})');
    }
  }

  static Future<List<String>> updateOrderStatus(int orderId, String status) async {
    final response = await _authenticatedRequest(
      () => http.put(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final warnings = data['warnings'] as List<dynamic>? ?? [];
      return warnings.map((e) => e.toString()).toList();
    } else {
      throw Exception('Failed to update status (${response.statusCode})');
    }
  }
  static Future<Map<String, dynamic>> getWarehouseStats() async {
    final response = await _authenticatedRequest(
      () => http.get(Uri.parse('$baseUrl/warehouse/stats'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stats (${response.statusCode})');
    }
  }
  static Future<void> requestStock(int medicineId) async {
    final response = await _authenticatedRequest(
      () => http.put(
        Uri.parse('$baseUrl/inventory/$medicineId/request'),
        headers: _headers,
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to request stock (${response.statusCode})');
    }
  }

  static Future<void> replenishStock(int medicineId) async {
    final response = await _authenticatedRequest(
      () => http.put(
        Uri.parse('$baseUrl/inventory/$medicineId/replenish'),
        headers: _headers,
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to replenish stock (${response.statusCode})');
    }
  }

  static Future<List<dynamic>> getDemandPrediction() async {
    final response = await _authenticatedRequest(
      () => http.get(
        Uri.parse('$baseUrl/analytics/demand'),
        headers: _headers,
      ),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load predictions (${response.statusCode})');
    }
  }

  // --- Admin ---
  static Future<List<dynamic>> getAllUsers() async {
    // Note: This endpoint doesn't exist yet, I'll add it to main.py later if needed
    // For now we'll just have the placeholder
     final response = await _authenticatedRequest(
      () => http.get(Uri.parse('$baseUrl/admin/users'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<void> cancelOrder(int orderId) async {
    final response = await _authenticatedRequest(
      () => http.delete(Uri.parse('$baseUrl/orders/$orderId/cancel'), headers: _headers),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel order (${response.statusCode})');
    }
  }

  // --- Payments ---
  static Future<Map<String, dynamic>> createPaymentIntent(double amount) async {
    final response = await _authenticatedRequest(
      () => http.post(
        Uri.parse('$baseUrl/payments/create-intent'),
        headers: _headers,
        body: jsonEncode({'amount': amount}),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create PaymentIntent (${response.statusCode})');
    }
  }

  // --- Document Verification ---
  static Future<Map<String, dynamic>> uploadDocument(
      String docType, String filePath, String fileName, List<int> fileBytes) async {
    final uri = Uri.parse('$baseUrl/documents/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $_token';
    request.fields['doc_type'] = docType;

    final ext = fileName.split('.').last.toLowerCase();
    String mimeType = 'application/octet-stream';
    if (ext == 'pdf') mimeType = 'application/pdf';
    if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
    if (ext == 'png') mimeType = 'image/png';

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(mimeType),
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      // Update local verification status
      await _prefs?.setBool('is_verified', true);
      return jsonDecode(response.body);
    } else {
      final detail = jsonDecode(response.body)['detail'] ?? 'Upload failed';
      throw Exception(detail);
    }
  }

  static Future<List<dynamic>> getMyDocuments() async {
    final response = await _authenticatedRequest(
      () => http.get(
        Uri.parse('$baseUrl/documents/my'),
        headers: _headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch documents');
    }
  }

  static Future<Map<String, dynamic>> getVerificationStatus() async {
    final response = await _authenticatedRequest(
      () => http.get(
        Uri.parse('$baseUrl/me/verification-status'),
        headers: _headers,
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _prefs?.setBool('is_verified', data['is_verified'] ?? false);
      return data;
    } else {
      throw Exception('Failed to fetch verification status');
    }
  }
}
