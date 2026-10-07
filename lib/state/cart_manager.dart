import 'package:flutter/foundation.dart';
import '../models/laundry_item.dart';

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
