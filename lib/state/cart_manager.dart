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

        String? subCategory = row['subCategory']?.toString();
        if (subCategory == null || subCategory.isEmpty) {
          if (code.startsWith('dc_m_')) subCategory = 'Men';
          else if (code.startsWith('dc_w_')) subCategory = 'Women';
          else if (code.startsWith('dc_k_')) subCategory = 'Kids';
          else if (code.startsWith('hh_h_')) subCategory = 'Home Items';
          else if (code.startsWith('hh_s_')) subCategory = 'Sofa Cleaning';
          else if (code.startsWith('hh_c_')) subCategory = 'Carpet Cleaning';
        }

        mapped.add(LaundryItem(
          id: code,
          name: name,
          category: category,
          subCategory: subCategory,
          price: (row['price'] as num?)?.round() ?? 0,
          unit: row['unit']?.toString() ?? 'pc',
          iconKey: row['iconKey']?.toString() ?? 'shirt',
          // keep anything already in the basket
          quantity: _quantityFor(code),
        ));
      }

      if (mapped.isNotEmpty) {
        if (mapped.length < _catalog.length) {
          debugPrint(
            'Live backend returned ${mapped.length} items while local has ${_catalog.length}. ' 
            'Preserving updated local catalog until backend is deployed and seeded.',
          );
        } else {
          _catalog
            ..clear()
            ..addAll(mapped);
          _catalogIsLive = true;
          notifyListeners();
        }
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

      // Steam Iron Items (Client List: 22 items)
      LaundryItem(
        id: 'si_1',
        name: 'Shirt',
        category: ServiceCategory.steamIron,
        price: 99,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_2',
        name: 'Jeans',
        category: ServiceCategory.steamIron,
        price: 99,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_3',
        name: 'Trouser',
        category: ServiceCategory.steamIron,
        price: 99,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_4',
        name: 'Starch Shirt',
        category: ServiceCategory.steamIron,
        price: 129,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_5',
        name: 'Starch Pant',
        category: ServiceCategory.steamIron,
        price: 129,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_6',
        name: 'T-Shirt',
        category: ServiceCategory.steamIron,
        price: 99,
        iconKey: 'tshirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_7',
        name: 'Kurta',
        category: ServiceCategory.steamIron,
        price: 129,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_8',
        name: 'Pyjama',
        category: ServiceCategory.steamIron,
        price: 129,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_9',
        name: 'Saree Fancy',
        category: ServiceCategory.steamIron,
        price: 249,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_10',
        name: 'Saree Pattu',
        category: ServiceCategory.steamIron,
        price: 299,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_11',
        name: 'Designer Saree',
        category: ServiceCategory.steamIron,
        price: 349,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_12',
        name: 'Fancy Blouse',
        category: ServiceCategory.steamIron,
        price: 49,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_13',
        name: 'Pattu Blouse',
        category: ServiceCategory.steamIron,
        price: 79,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_14',
        name: 'Designer Blouse',
        category: ServiceCategory.steamIron,
        price: 99,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_15',
        name: 'Lehanga Bottom',
        category: ServiceCategory.steamIron,
        price: 249,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_16',
        name: 'Lehanga with Can-Can',
        category: ServiceCategory.steamIron,
        price: 349,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_17',
        name: 'Lehanga Blouse',
        category: ServiceCategory.steamIron,
        price: 79,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_18',
        name: 'Lehanga Blouse Designer',
        category: ServiceCategory.steamIron,
        price: 129,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_19',
        name: 'Anarkali',
        category: ServiceCategory.steamIron,
        price: 249,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_20',
        name: 'Dupatta',
        category: ServiceCategory.steamIron,
        price: 149,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_21',
        name: 'Dupatta Designer',
        category: ServiceCategory.steamIron,
        price: 199,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'si_22',
        name: 'Chunni',
        category: ServiceCategory.steamIron,
        price: 79,
        iconKey: 'saree',
        quantity: 0,
      ),

      // ==========================================
      // Dry Cleaning Items (Sub-categories: Men, Women, Kids - 55 Items)
      // ==========================================

      // --- 1. MEN - DRY CLEANING (22 Items) ---
      LaundryItem(
        id: 'dc_m_1',
        name: 'Waist Coat',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 149,
        iconKey: 'suit',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_2',
        name: 'Kurta Pyjama (Light)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 199,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_3',
        name: 'Kurta Pyjama (Heavy)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 349,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_4',
        name: 'Coat Short',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 299,
        iconKey: 'coat',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_5',
        name: 'Jacket Short',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 249,
        iconKey: 'jacket',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_6',
        name: 'Overcoat',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 359,
        iconKey: 'coat',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_7',
        name: 'Safari Shirt & Pant – Cotton',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 249,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_8',
        name: 'Shirt (Half / Full)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 109,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_9',
        name: 'Short',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 69,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_10',
        name: 'Socks Pair',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 49,
        unit: 'pair',
        iconKey: 'socks',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_11',
        name: 'Suit 2 Pc',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 359,
        iconKey: 'suit',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_12',
        name: 'Suit 3 Pc',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 449,
        iconKey: 'suit',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_13',
        name: 'Sweater / Cardigan – Full Sleeve',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 199,
        iconKey: 'sweater',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_14',
        name: 'Sweater / Cardigan – Sleeveless',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 169,
        iconKey: 'sweater',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_15',
        name: 'Shawl / Lohi',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 199,
        iconKey: 'scarf',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_16',
        name: 'Tie',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 69,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_17',
        name: 'Pants / Trousers',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 129,
        iconKey: 'pants',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_18',
        name: 'Jeans',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 139,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_19',
        name: 'T-Shirt',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 109,
        iconKey: 'tshirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_20',
        name: 'Dhoti / Lungi (Silk)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 119,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_21',
        name: 'Shirt & Dhoti (Silk)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 179,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_m_22',
        name: 'Undergarment',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Men',
        price: 49,
        iconKey: 'shirt',
        quantity: 0,
      ),

      // --- 2. WOMEN - DRY CLEANING (19 Items) ---
      LaundryItem(
        id: 'dc_w_1',
        name: 'Blouse / Top',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 99,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_2',
        name: 'Choli + Lehanga + Dupatta',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 699,
        iconKey: 'lehanga',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_3',
        name: 'Dress (Cotton)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 219,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_4',
        name: 'Dress (Heavy)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 449,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_5',
        name: 'Dupatta',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 99,
        iconKey: 'dupatta',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_6',
        name: 'Kameez / Kurta',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 119,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_7',
        name: 'Pyjama / Pants / Salwar / Churidar / Palazo Pants',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 99,
        iconKey: 'pants',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_8',
        name: 'Kurta + Pyjama / Salwar / Churidar',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 199,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_9',
        name: 'Kurta + Pyjamas / Salwar / Churidar + Dupatta',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 299,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_10',
        name: 'Lehanga / Flared Skirt',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 359,
        iconKey: 'lehanga',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_11',
        name: 'Saree (Cotton / Synthetic / Light)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 199,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_12',
        name: 'Saree (Silk / Chiffon / Georgette / Pattu / Heavy)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 299,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_13',
        name: 'Saree (Embroidered / Heavy)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 349,
        iconKey: 'saree',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_14',
        name: 'Petti Coat',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 79,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_15',
        name: 'Sherwani / Achkan',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 359,
        iconKey: 'suit',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_16',
        name: 'Skirt – Pencil / Pleated / Other',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 119,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_17',
        name: 'Stocking (Pair) – Regular',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 69,
        unit: 'pair',
        iconKey: 'socks',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_18',
        name: 'Stole / Scarf',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 69,
        iconKey: 'scarf',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_w_19',
        name: 'Shorts',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Women',
        price: 59,
        iconKey: 'jeans',
        quantity: 0,
      ),

      // --- 3. KIDS - DRY CLEANING (14 Items) ---
      LaundryItem(
        id: 'dc_k_1',
        name: 'Blouse / Top',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 69,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_2',
        name: 'Choli / Lehenga Dupatta',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 399,
        iconKey: 'lehanga',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_3',
        name: 'Dress (Heavy)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 249,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_4',
        name: 'Skirt',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 89,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_5',
        name: 'Frock',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 119,
        iconKey: 'frock',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_6',
        name: 'Kurta + Pants / Salwar / Churidar + Dupatta',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 299,
        iconKey: 'dress',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_7',
        name: 'Shorts',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 49,
        iconKey: 'jeans',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_8',
        name: 'T-Shirt',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 69,
        iconKey: 'tshirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_9',
        name: 'Coat',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 179,
        iconKey: 'coat',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_10',
        name: 'Jacket',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 149,
        iconKey: 'jacket',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_11',
        name: '2 Pc Suit',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 239,
        iconKey: 'suit',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_12',
        name: '3 Pc Suit',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 299,
        iconKey: 'suit',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_13',
        name: 'Sweater (Full Sleeves)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 129,
        iconKey: 'sweater',
        quantity: 0,
      ),
      LaundryItem(
        id: 'dc_k_14',
        name: 'Sweater (Sleeveless)',
        category: ServiceCategory.dryCleaning,
        subCategory: 'Kids',
        price: 109,
        iconKey: 'sweater',
        quantity: 0,
      ),

      // Shoe Cleaning Items (Client List: Shoes)
      LaundryItem(
        id: 'sc_1',
        name: 'Canvas (Cloth)',
        category: ServiceCategory.shoeCleaning,
        price: 349,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_2',
        name: 'Leather Shoes',
        category: ServiceCategory.shoeCleaning,
        price: 349,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_3',
        name: 'Formal Shoes',
        category: ServiceCategory.shoeCleaning,
        price: 349,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_4',
        name: 'Sneakers',
        category: ServiceCategory.shoeCleaning,
        price: 449,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_5',
        name: 'Boots',
        category: ServiceCategory.shoeCleaning,
        price: 449,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_6',
        name: 'Hiking Shoes',
        category: ServiceCategory.shoeCleaning,
        price: 549,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_7',
        name: 'Sports Shoes',
        category: ServiceCategory.shoeCleaning,
        price: 249,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),
      LaundryItem(
        id: 'sc_8',
        name: 'Suede Leather Shoes',
        category: ServiceCategory.shoeCleaning,
        price: 349,
        unit: 'pair',
        iconKey: 'shoes',
        quantity: 0,
      ),

      // ==========================================
      // Household Items (Sub-categories: Home Items, Sofa Cleaning, Carpet Cleaning - 38 Items)
      // ==========================================

      // --- 1. HOME - HOUSEHOLD ITEMS (34 Items) ---
      LaundryItem(
        id: 'hh_h_1',
        name: 'Bath Mat',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 49,
        iconKey: 'mat',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_2',
        name: 'Bath Robe (Small)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 59,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_3',
        name: 'Bath Robe (Big)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 89,
        iconKey: 'shirt',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_4',
        name: 'Bath Towel',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 59,
        iconKey: 'towel',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_5',
        name: 'Bed Cover (Single)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 249,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_6',
        name: 'Bed Cover (Double/King)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 349,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_7',
        name: 'Bed Sheet (Single)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 119,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_8',
        name: 'Bed Sheet (Double/King)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 199,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_9',
        name: 'Blanket (Single)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 349,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_10',
        name: 'Blanket (Double/King)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 449,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_11',
        name: 'Cushion Cover (Small)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 69,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_12',
        name: 'Cushion Cover (Medium)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 119,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_13',
        name: 'Pillow Cover – Cotton',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 49,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_14',
        name: 'Pillow Cover – Embroidery',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 99,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_15',
        name: 'Quilt (Single)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 449,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_16',
        name: 'Quilt (Double/King)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 549,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_17',
        name: 'Quilt Cover (Single)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 249,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_18',
        name: 'Quilt Cover (Double/King)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 349,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_19',
        name: 'Stuffed Toy (Small)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 119,
        iconKey: 'toy',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_20',
        name: 'Stuffed Toy (Medium)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 199,
        iconKey: 'toy',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_21',
        name: 'Stuffed Toy (Big)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 299,
        iconKey: 'toy',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_22',
        name: 'Curtain – Without Lining (Per Panel)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 239,
        unit: 'panel',
        iconKey: 'curtain',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_23',
        name: 'Curtain – With Lining (Per Panel)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 349,
        unit: 'panel',
        iconKey: 'curtain',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_24',
        name: 'Face Towel',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 39,
        iconKey: 'towel',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_25',
        name: 'Hand Towel',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 49,
        iconKey: 'towel',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_26',
        name: 'Sofa Cover (Per Seat)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 119,
        unit: 'seat',
        iconKey: 'sofa',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_27',
        name: 'Table Cloth (Small)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 89,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_28',
        name: 'Table Cloth (Big)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 149,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_29',
        name: 'Table Runner – Fancy',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 179,
        iconKey: 'bedsheet',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_30',
        name: 'Foot Mat (1 ft × 2 ft)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 59,
        iconKey: 'mat',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_31',
        name: 'Pram',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 399,
        iconKey: 'kids',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_32',
        name: 'Suitcase (Small)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 249,
        iconKey: 'suitcase',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_33',
        name: 'Suitcase (Medium)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 399,
        iconKey: 'suitcase',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_h_34',
        name: 'Suitcase (Big)',
        category: ServiceCategory.household,
        subCategory: 'Home Items',
        price: 499,
        iconKey: 'suitcase',
        quantity: 0,
      ),

      // --- 2. SOFA CLEANING (3 Items) ---
      LaundryItem(
        id: 'hh_s_1',
        name: 'Cotton & Synthetic',
        category: ServiceCategory.household,
        subCategory: 'Sofa Cleaning',
        price: 299,
        unit: 'seat',
        iconKey: 'sofa',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_s_2',
        name: 'Silk, Velvet & Jute',
        category: ServiceCategory.household,
        subCategory: 'Sofa Cleaning',
        price: 399,
        unit: 'seat',
        iconKey: 'sofa',
        quantity: 0,
      ),
      LaundryItem(
        id: 'hh_s_3',
        name: 'Leather',
        category: ServiceCategory.household,
        subCategory: 'Sofa Cleaning',
        price: 499,
        unit: 'seat',
        iconKey: 'sofa',
        quantity: 0,
      ),

      // --- 3. CARPET CLEANING (1 Item) ---
      LaundryItem(
        id: 'hh_c_1',
        name: 'Carpet Cleaning',
        category: ServiceCategory.household,
        subCategory: 'Carpet Cleaning',
        price: 30,
        unit: 'sq.ft',
        iconKey: 'carpet',
        quantity: 0,
      ),
    ]);
  }

  List<LaundryItem> get selectedItems =>
      _catalog.where((item) => item.quantity > 0).toList();

  /// True if cart contains items belonging to Wash & Fold or Wash & Iron
  bool get hasWashWeightItems => selectedItems.any((item) =>
      item.category == ServiceCategory.washAndFold ||
      item.category == ServiceCategory.washAndIron);

  int get totalItemCount =>
      _catalog.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal =>
      _catalog.fold(0, (sum, item) => sum + (item.price * item.quantity));

  static const int freeDeliveryThreshold = 299;
  static const int standardDeliveryFee = 60;

  /// Orders >= ₹299 get FREE delivery. Orders < ₹299 incur ₹60 delivery fee.
  int get deliveryFee {
    if (subtotal == 0 || subtotal >= freeDeliveryThreshold) return 0;
    return standardDeliveryFee;
  }

  int get discountAmount {
    if (!_couponApplied || subtotal == 0) return 0;
    return (subtotal * (_couponDiscountPercent / 100)).round();
  }

  int get grandTotal {
    if (subtotal == 0) return 0;
    final total = subtotal - discountAmount + deliveryFee;
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
