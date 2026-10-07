import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  ApiClient._internal();

  static const String baseUrl = 'http://yesdhobi-alb-648458477.ap-southeast-2.elb.amazonaws.com/api/v1';

  String? _accessToken;
  String? _refreshToken;
  bool _isRefreshing = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> setTokens({required String accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  Future<void> clearAuth() async {
    _accessToken = null;
    _refreshToken = null;
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

  /// Attempts silent refresh using refresh_token if the access token has expired
  Future<bool> _attemptTokenRefresh() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentRefresh = _refreshToken ?? prefs.getString('refresh_token');

      if (currentRefresh == null || currentRefresh.isEmpty) {
        _isRefreshing = false;
        return false;
      }

      final url = Uri.parse('$baseUrl/auth/refresh');
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': currentRefresh}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('accessToken')) {
          final newAccess = decoded['accessToken'].toString();
          final newRefresh = decoded['refreshToken']?.toString() ?? currentRefresh;
          await setTokens(accessToken: newAccess, refreshToken: newRefresh);
          _isRefreshing = false;
          return true;
        }
      }
    } catch (_) {}

    _isRefreshing = false;
    return false;
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    if (_accessToken == null) await init();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http
          .get(url, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          final retryResponse = await http
              .get(url, headers: _buildHeaders())
              .timeout(const Duration(seconds: 15));
          return _parseResponse(retryResponse);
        }
      }

      return _parseResponse(response);
    } on http.ClientException {
      throw Exception('Unable to reach Yes Dhobi server. Please check your internet connection.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server request timed out. Please try again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    if (_accessToken == null) await init();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          final retryResponse = await http
              .post(
                url,
                headers: _buildHeaders(),
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 15));
          return _parseResponse(retryResponse);
        }
      }

      return _parseResponse(response);
    } on http.ClientException {
      throw Exception('Unable to reach Yes Dhobi server. Please check your internet connection.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server request timed out. Please try again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> body) async {
    if (_accessToken == null) await init();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http
          .patch(
            url,
            headers: _buildHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          final retryResponse = await http
              .patch(
                url,
                headers: _buildHeaders(),
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 15));
          return _parseResponse(retryResponse);
        }
      }

      return _parseResponse(response);
    } on http.ClientException {
      throw Exception('Unable to reach Yes Dhobi server. Please check your internet connection.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server request timed out. Please try again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    if (_accessToken == null) await init();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http
          .delete(url, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          final retryResponse = await http
              .delete(url, headers: _buildHeaders())
              .timeout(const Duration(seconds: 15));
          return _parseResponse(retryResponse);
        }
      }

      return _parseResponse(response);
    } on http.ClientException {
      throw Exception('Unable to reach Yes Dhobi server. Please check your internet connection.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server request timed out. Please try again.');
      }
      rethrow;
    }
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
