import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class CustomerApiService {
  static final CustomerApiService instance = CustomerApiService._internal();
  CustomerApiService._internal();

  final ApiClient _client = ApiClient.instance;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final tenDigits = cleaned.length >= 10 ? cleaned.substring(cleaned.length - 10) : cleaned;
    return await _client.post('/auth/customer/request-otp', {'phone': tenDigits});
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp, {
    String? name,
    String? email,
    String? referralCode,
  }) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final tenDigits = cleaned.length >= 10 ? cleaned.substring(cleaned.length - 10) : cleaned;

    final body = <String, dynamic>{
      'phone': tenDigits,
      'otp': otp.trim(),
    };
    if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
    if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      body['referralCode'] = referralCode.trim();
    }

    final res = await _client.post('/auth/customer/verify-otp', body);

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

  Future<Map<String, dynamic>> socialLogin({
    required String provider, // 'GOOGLE' or 'APPLE'
    required String email,
    required String name,
    String? phone,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{
      'provider': provider,
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
    };
    if (phone != null && phone.trim().isNotEmpty) {
      final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
      body['phone'] = cleaned.length >= 10 ? cleaned.substring(cleaned.length - 10) : cleaned;
    }
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    final res = await _client.post('/auth/customer/social', body);

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

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken != null) {
        await _client.post('/auth/logout', {'refreshToken': refreshToken});
      }
    } catch (_) {}
    await _client.clearAuth();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _client.get('/customers/me');
    try {
      final prefs = await SharedPreferences.getInstance();
      if (res.containsKey('user') && res['user'] != null) {
        await prefs.setString('user_data', jsonEncode(res['user']));
      }
    } catch (_) {}
    return res;
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? email, String? city}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (city != null) body['city'] = city;
    final res = await _client.patch('/customers/me', body);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(res));
    return res;
  }

  // ---------------------------------------------------------------------------
  // Addresses
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAddresses() async {
    final res = await _client.get('/customers/me/addresses');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  Future<Map<String, dynamic>> createAddress({
    String label = 'Home',
    required String line1,
    String? line2,
    String? landmark,
    String city = 'Hyderabad',
    String pincode = '500081',
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    return await _client.post('/customers/me/addresses', {
      'label': label,
      'line1': line1,
      if (line2 != null && line2.isNotEmpty) 'line2': line2,
      if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
      'city': city,
      'pincode': pincode,
      'lat': ?lat,
      'lng': ?lng,
      'isDefault': isDefault,
    });
  }

  Future<Map<String, dynamic>> updateAddress(String id, Map<String, dynamic> data) async {
    return await _client.patch('/customers/me/addresses/$id', data);
  }

  Future<Map<String, dynamic>> deleteAddress(String id) async {
    return await _client.delete('/customers/me/addresses/$id');
  }

  // ---------------------------------------------------------------------------
  // Catalog & Promo
  // ---------------------------------------------------------------------------

  /// The live price list. Codes here (wf_1, wi_3 ...) are the same ones
  /// `placeOrder` sends back, so prices can never drift from what we charge.
  Future<List<Map<String, dynamic>>> getCatalogItems() async {
    final res = await _client.get('/catalog/items');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  /// Help-centre articles. Optionally filtered by the server-side search.
  Future<List<Map<String, dynamic>>> getFaqs({String? query}) async {
    final suffix = (query == null || query.trim().isEmpty)
        ? ''
        : '?q=${Uri.encodeQueryComponent(query.trim())}';
    final res = await _client.get('/support/faqs$suffix');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  /// Phone / WhatsApp / email the customer can reach support on.
  Future<Map<String, dynamic>> getSupportChannels() async {
    return await _client.get('/support/channels');
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    String? orderId,
  }) async {
    return await _client.post('/support/tickets', {
      'subject': subject,
      'message': message,
      'orderId': ?orderId,
    });
  }

  Future<List<Map<String, dynamic>>> getPromotions() async {
    final res = await _client.get('/catalog/promotions');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required List<Map<String, dynamic>> items,
    bool isExpress = false,
  }) async {
    return await _client.post('/orders/validate-coupon', {
      'code': code.trim(),
      'items': items,
      'isExpress': isExpress,
    });
  }

  Future<List<Map<String, dynamic>>> getPickupSlots() async {
    final res = await _client.get('/catalog/slots');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

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

  Future<List<Map<String, dynamic>>> getOrders({String status = 'all'}) async {
    final res = await _client.get('/orders?status=$status');
    if (res.containsKey('data') && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    return await getOrders(status: 'active');
  }

  Future<Map<String, dynamic>> getOrderById(String id) async {
    return await _client.get('/orders/$id');
  }

  Future<Map<String, dynamic>> trackOrder(String id) async {
    return await _client.get('/orders/$id/track');
  }

  Future<Map<String, dynamic>> getOrderInvoice(String id) async {
    return await _client.get('/orders/$id/invoice');
  }

  Future<Map<String, dynamic>> getReferralInfo() async {
    return await _client.get('/customers/me/referrals');
  }
}
