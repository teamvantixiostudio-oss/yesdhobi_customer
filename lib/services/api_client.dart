import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  ApiClient._internal();

  static const String baseUrl = 'http://yesdhobi-alb-648458477.ap-southeast-2.elb.amazonaws.com/api/v1';

  String? _accessToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
  }

  Future<void> setTokens({required String accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  Future<void> clearAuth() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
    await prefs.remove('customer_data');
  }

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> _buildHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    if (_accessToken == null) await init();
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http
        .get(url, headers: _buildHeaders())
        .timeout(const Duration(seconds: 15));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    if (_accessToken == null) await init();
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http
        .post(
          url,
          headers: _buildHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Server error: HTTP ${response.statusCode}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } else {
      String msg = 'Request failed (${response.statusCode})';
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('message')) {
          msg = decoded['message'].toString();
        } else if (decoded.containsKey('error') && decoded['error'] is Map) {
          msg = decoded['error']['message'] ?? msg;
        }
      }
      throw Exception(msg);
    }
  }
}
