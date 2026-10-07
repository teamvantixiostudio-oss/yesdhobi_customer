import 'package:flutter/foundation.dart';
import '../models/laundry_item.dart';
import '../services/customer_api_service.dart';

class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal() {
    _initializeCatalog();
  }

  final List<LaundryItem> _catalog = [];
  String _selectedDate = 'Today, 24';
  String _selectedSlot = '6-8 PM';
  String _pickupAddress = 'Flat 402, Green Glen Layout, Outer Ring...';
  String? _selectedAddressId;
  double? _pickupLat;
  double? _pickupLng;
  String _pickupInstructions = '';
  bool _couponApplied = false;
  String _couponCode = 'FIRSTORDER';
  int _couponDiscountPercent = 20;

  List<LaundryItem> get catalog => _catalog;

  /// True once the price list has come from the server rather than the
  /// built-in fallback.
  bool get catalogIsLive => _catalogIsLive;
  bool _catalogIsLive = false;
  bool _catalogLoading = false;

  /// Pull the live price list. The hardcoded catalogue below stays as the
  /// offline fallback, so the app still works with no network - but whenever
  /// the server answers, its prices win. Without this, a price changed in the
  /// admin panel never reached the app and the customer was quoted one figure
  /// while the server charged another.
  Future<void> loadCatalogFromServer({bool force = false}) async {
    if (_catalogLoading) return;
    if (_catalogIsLive && !force) return;
    _catalogLoading = true;
    try {
      final rows = await CustomerApiService.instance.getCatalogItems();
      final mapped = <LaundryItem>[];
      for (final row in rows) {
        final code = row['code']?.toString();
        final name = row['name']?.toString();
        if (code == null || code.isEmpty || name == null || name.isEmpty) continue;

        final service = row['serviceCategory'];
        final category = serviceCategoryFromCode(
          service is Map ? service['code']?.toString() : null,
        );
        if (category == null) continue; // a service this build has no tab for

        mapped.add(LaundryItem(
          id: code,
          name: name,
          category: category,
          price: (row['price'] as num?)?.round() ?? 0,
          unit: row['unit']?.toString() ?? 'pc',
          iconKey: row['iconKey']?.toString() ?? 'shirt',
          // keep anything already in the basket
          quantity: _quantityFor(code),
        ));
      }

      if (mapped.isNotEmpty) {
        _catalog
          ..clear()
          ..addAll(mapped);
        _catalogIsLive = true;
        notifyListeners();
      }
    } catch (e) {
      // keep the fallback prices; the basket still works offline
      debugPrint('Could not load the live price list: $e');
    } finally {
      _catalogLoading = false;
    }
  }

  int _quantityFor(String id) {
    for (final item in _catalog) {
      if (item.id == id) return item.quantity;
    }
    return 0;
  }
  String get selectedDate => _selectedDate;
  String get selectedSlot => _selectedSlot;
  String get pickupAddress => _pickupAddress;
  String? get selectedAddressId => _selectedAddressId;
  double? get pickupLat => _pickupLat;
  double? get pickupLng => _pickupLng;
  String get pickupInstructions => _pickupInstructions;
  bool get couponApplied => _couponApplied;
  String get couponCode => _couponCode;
  int get couponDiscountPercent => _couponDiscountPercent;

  void _initializeCatalog() {
    _catalog.clear();
    _catalog.addAll([
      // Wash & Fold Items
      LaundryItem(
        id: 'wf_1',
        name: 'Shirt',
        category: ServiceCategory.washAndFold,
        price: 40,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wf_2',
        name: 'T-Shirt',
        category: ServiceCategory.washAndFold,
        price: 30,
        iconKey: 'tshirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wf_3',
        name: 'Jeans',
        category: ServiceCategory.washAndFold,
        price: 50,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wf_4',
        name: 'Saree',
        category: ServiceCategory.washAndFold,
        price: 80,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wf_5',
        name: 'Bedsheet',
        category: ServiceCategory.washAndFold,
        price: 120,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wf_6',
        name: 'Towel',
        category: ServiceCategory.washAndFold,
        price: 35,
        iconKey: 'towel',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wf_7',
        name: 'Kurta',
        category: ServiceCategory.washAndFold,
        price: 45,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wf_8',
        name: 'Shorts / Pyjamas',
        category: ServiceCategory.washAndFold,
        price: 30,
        iconKey: 'jeans',
        quantity: 0,
      ),

      // Wash & Iron Items
      LaundryItem(
        id: 'wi_1',
        name: 'Shirt',
        category: ServiceCategory.washAndIron,
        price: 40,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wi_2',
        name: 'T-Shirt',
        category: ServiceCategory.washAndIron,
        price: 30,
        iconKey: 'tshirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wi_3',
        name: 'Formal Trousers',
        category: ServiceCategory.washAndIron,
        price: 50,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wi_4',
        name: 'Silk / Cotton Saree',
        category: ServiceCategory.washAndIron,
        price: 110,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'wi_5',
        name: 'Double Bedsheet',
        category: ServiceCategory.washAndIron,
        price: 90,
        iconKey: 'bedsheet',
        quantity: 0,
      ),

      // Steam Iron Items
      LaundryItem(
        id: 'si_1',
        name: 'Shirt / Top',
        category: ServiceCategory.steamIron,
        price: 25,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_2',
        name: 'T-Shirt',
        category: ServiceCategory.steamIron,
        price: 20,
        iconKey: 'tshirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_3',
        name: 'Trousers / Jeans',
        category: ServiceCategory.steamIron,
        price: 30,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_4',
        name: 'Saree Press',
        category: ServiceCategory.steamIron,
        price: 50,
        iconKey: 'saree',
        quantity: 0,
      ),

      // Dry Cleaning Items
      LaundryItem(
        id: 'dc_1',
        name: '2-Piece Suit',
        category: ServiceCategory.dryCleaning,
        price: 299,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_2',
        name: 'Heavy Saree / Lehenga',
        category: ServiceCategory.dryCleaning,
        price: 199,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_3',
        name: 'Blazer / Coat',
        category: ServiceCategory.dryCleaning,
        price: 180,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_4',
        name: 'Winter Jacket / Sweater',
        category: ServiceCategory.dryCleaning,
        price: 149,
        iconKey: 'shirt',
        quantity: 0,
      ),

      // Shoe Cleaning Items
      LaundryItem(
        id: 'sc_1',
        name: 'Sneakers / Sports Shoes',
        category: ServiceCategory.shoeCleaning,
        price: 199,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_2',
        name: 'Leather Shoes Spa',
        category: ServiceCategory.shoeCleaning,
        price: 249,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_3',
        name: 'Suede / Boots',
        category: ServiceCategory.shoeCleaning,
        price: 299,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),

      // Household Items
      LaundryItem(
        id: 'hh_1',
        name: 'Quilt / Comforter',
        category: ServiceCategory.household,
        price: 299,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_2',
        name: 'Curtains (Pair)',
        category: ServiceCategory.household,
        price: 349,
        iconKey: 'towel',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_3',
        name: 'Blanket (Double)',
        category: ServiceCategory.household,
        price: 249,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
    ]);
  }

  List<LaundryItem> get selectedItems =>
      _catalog.where((item) => item.quantity > 0).toList();

  int get totalItemCount =>
      _catalog.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal =>
      _catalog.fold(0, (sum, item) => sum + (item.price * item.quantity));

  int get discountAmount {
    if (!_couponApplied || subtotal == 0) return 0;
    return (subtotal * (_couponDiscountPercent / 100)).round();
  }

  int get grandTotal {
    final total = subtotal - discountAmount;
    return total < 0 ? 0 : total;
  }

  void incrementItem(String id) {
    final index = _catalog.indexWhere((item) => item.id == id);
    if (index != -1) {
      _catalog[index].quantity++;
      notifyListeners();
    }
  }

  void decrementItem(String id) {
    final index = _catalog.indexWhere((item) => item.id == id);
    if (index != -1 && _catalog[index].quantity > 0) {
      _catalog[index].quantity--;
      notifyListeners();
    }
  }

  void setPickupDate(String date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setPickupSlot(String slot) {
    _selectedSlot = slot;
    notifyListeners();
  }

  void setPickupAddress(String address, {String? addressId, double? lat, double? lng}) {
    _pickupAddress = address;
    if (addressId != null) {
      _selectedAddressId = addressId;
    }
    if (lat != null) _pickupLat = lat;
    if (lng != null) _pickupLng = lng;
    notifyListeners();
  }

  void setCoordinates(double lat, double lng) {
    _pickupLat = lat;
    _pickupLng = lng;
    notifyListeners();
  }

  void setSelectedAddressId(String? id) {
    _selectedAddressId = id;
    notifyListeners();
  }

  void setPickupInstructions(String instructions) {
    _pickupInstructions = instructions;
    notifyListeners();
  }

  void toggleCoupon() {
    _couponApplied = !_couponApplied;
    notifyListeners();
  }

  void applyCoupon(String code, {int discountPercent = 20}) {
    _couponCode = code.toUpperCase();
    _couponDiscountPercent = discountPercent > 0 ? discountPercent : 20;
    _couponApplied = true;
    notifyListeners();
  }

  void clearCart() {
    for (var item in _catalog) {
      item.quantity = 0;
    }
    notifyListeners();
  }
}
