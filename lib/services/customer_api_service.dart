import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class CustomerApiService {
  static final CustomerApiService instance = CustomerApiService._internal();
  CustomerApiService._internal();

  final ApiClient _client = ApiClient.instance;

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    // Normalise phone number to 10 digits or E.164
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final tenDigits = cleaned.length >= 10 ? cleaned.substring(cleaned.length - 10) : cleaned;
    return await _client.post('/auth/customer/request-otp', {'phone': tenDigits});
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final tenDigits = cleaned.length >= 10 ? cleaned.substring(cleaned.length - 10) : cleaned;
    
    final res = await _client.post('/auth/customer/verify-otp', {
      'phone': tenDigits,
      'otp': otp.trim(),
    });

    if (res.containsKey('accessToken')) {
      await _client.setTokens(
        accessToken: res['accessToken'],
        refreshToken: res['refreshToken'],
      );

      final prefs = await SharedPreferences.getInstance();
      if (res.containsKey('user')) {
        await prefs.setString('user_data', jsonEncode(res['user']));
      }
      if (res.containsKey('customer')) {
        await prefs.setString('customer_data', jsonEncode(res['customer']));
      }
    }
    return res;
  }

  Future<List<Map<String, dynamic>>> getAddresses() async {
    final res = await _client.get('/customers/me/addresses');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  Future<Map<String, dynamic>> createAddress({
    String label = 'Home',
    String line1 = 'Flat 204, Green Heights, Hi-Tech City',
    String city = 'Hyderabad',
    String pincode = '500081',
  }) async {
    return await _client.post('/customers/me/addresses', {
      'label': label,
      'line1': line1,
      'city': city,
      'pincode': pincode,
      'isDefault': true,
    });
  }

  Future<Map<String, dynamic>> quoteOrder({
    required List<Map<String, dynamic>> items,
    String? promoCode,
    bool isExpress = false,
  }) async {
    final body = <String, dynamic>{
      'items': items,
      'isExpress': isExpress,
    };
    if (promoCode != null && promoCode.trim().isNotEmpty) {
      body['promoCode'] = promoCode.trim();
    }
    return await _client.post('/orders/quote', body);
  }

  Future<Map<String, dynamic>> placeOrder({
    required List<Map<String, dynamic>> items,
    required String addressId,
    required String pickupDate,
    required String pickupSlot,
    String paymentMethod = 'COD',
    String? promoCode,
    String? notes,
    bool isExpress = false,
  }) async {
    final body = <String, dynamic>{
      'items': items,
      'addressId': addressId,
      'pickupDate': pickupDate,
      'pickupSlot': pickupSlot,
      'paymentMethod': paymentMethod,
      'isExpress': isExpress,
    };
    if (promoCode != null && promoCode.trim().isNotEmpty) {
      body['promoCode'] = promoCode.trim();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      body['notes'] = notes.trim();
    }
    return await _client.post('/orders', body);
  }

  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final res = await _client.get('/orders?status=active');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }
}
