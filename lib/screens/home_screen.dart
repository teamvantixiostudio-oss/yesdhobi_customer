import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/laundry_item.dart';
import '../services/customer_api_service.dart';
import '../services/location_service.dart';
import '../state/cart_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/promo_launch_popup.dart';
import '../widgets/location_selection_sheet.dart';
import '../widgets/yes_dhobi_logo.dart';
import 'package:geolocator/geolocator.dart';
import 'select_items_screen.dart';
import 'track_order_screen.dart';
import 'manage_addresses_screen.dart';
import 'help_support_screen.dart';
import 'order_details_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;

  const HomeScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedBottomNav;
  String _selectedLocation = 'Choose delivery location';
  int _selectedOrderFilter = 0; // 0: Active, 1: Completed, 2: Cancelled

  String _userName = 'Customer';
  String _userEmail = '';
  String _userPhone = '';
  String _referralCode = '';
  List<Map<String, dynamic>> _promotions = [];
  List<Map<String, dynamic>> _realOrders = [];
  bool _isLoadingOrders = false;
  Map<String, dynamic>? _topActiveOrder;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedBottomNav = widget.initialTab;
    _loadUserDataAndOrders();

    // Ensure absolutely no lingering snackbars from previous auth screens bleed onto home
    clearAllAppSnackBars();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        clearAllAppSnackBars(context);
      }
      _checkLocationOnLaunch();
    });
  }

  Future<void> _checkLocationOnLaunch() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      final hasGpsPermission = isServiceEnabled &&
          (permission == LocationPermission.always || permission == LocationPermission.whileInUse);

      if (hasGpsPermission) {
        final geo = await LocationService.instance.getCurrentLocationAddress();
        if (mounted && geo != null && geo.area.isNotEmpty) {
          setState(() {
            _selectedLocation = '📍 ${geo.area}, ${geo.city}';
          });
          CartManager.instance.setPickupAddress(
            geo.formatted,
            lat: geo.latitude,
            lng: geo.longitude,
          );
          return;
        }
      }

      // If location is not enabled or user has not yet chosen an address in this session,
      // prompt the location selection bottom sheet with options to enable GPS or pick saved addresses
      final hasChosen = CartManager.instance.pickupAddress.trim().isNotEmpty &&
          !CartManager.instance.pickupAddress.toLowerCase().contains('choose');

      if (!hasChosen) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showLocationPermissionDialog();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showLocationPermissionDialog();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString('user_data');
    if (userRaw != null) {
      try {
        final u = jsonDecode(userRaw);
        if (u['name'] != null && u['name'].toString().isNotEmpty) {
          _userName = u['name'].toString();
        }
        if (u['phone'] != null) _userPhone = u['phone'].toString();
        if (u['email'] != null) _userEmail = u['email'].toString();
      } catch (_) {}
    }

    try {
      final profile = await CustomerApiService.instance.getProfile();
      final u = profile['user'] ?? profile;
      if (u is Map) {
        if (u['name'] != null && u['name'].toString().isNotEmpty) {
          _userName = u['name'].toString();
        }
        if (u['phone'] != null) _userPhone = u['phone'].toString();
        if (u['email'] != null) _userEmail = u['email'].toString();
        await prefs.setString('user_data', jsonEncode(u));
      }
      if (profile['referralCode'] != null && profile['referralCode'].toString().isNotEmpty) {
        _referralCode = profile['referralCode'].toString();
      } else if (profile['customer'] is Map && profile['customer']['referralCode'] != null) {
        _referralCode = profile['customer']['referralCode'].toString();
      }
    } catch (_) {}

    try {
      final promos = await CustomerApiService.instance.getPromotions();
      if (mounted && promos.isNotEmpty) {
        setState(() => _promotions = promos);
      }
    } catch (_) {}

    try {
      final addrs = await CustomerApiService.instance.getAddresses();
      if (addrs.isNotEmpty) {
        final def = addrs.firstWhere((a) => a['isDefault'] == true, orElse: () => addrs.first);
        final tag = def['label']?.toString() ?? 'Home';
        final line1 = def['line1']?.toString() ?? def['street']?.toString() ?? '';
        final city = def['city']?.toString() ?? 'Hyderabad';
        final area = line1.isNotEmpty ? line1 : city;
        _selectedLocation = '$tag - $area';
      }
    } catch (_) {}

    try {
      final active = await CustomerApiService.instance.getActiveOrders();
      if (active.isNotEmpty) {
        _topActiveOrder = active.first;
      } else {
        _topActiveOrder = null;
      }
    } catch (_) {}

    _fetchOrdersByFilter(_selectedOrderFilter);
    if (mounted) setState(() {});
  }

  Future<void> _fetchOrdersByFilter(int filterIndex) async {
    if (!mounted) return;
    setState(() => _isLoadingOrders = true);
    String status = 'all';
    if (filterIndex == 0) {
      status = 'active';
    } else if (filterIndex == 1) {
      status = 'completed';
    } else if (filterIndex == 2) {
      status = 'cancelled';
    }

    try {
      final list = await CustomerApiService.instance.getOrders(status: status);
      if (mounted) {
        setState(() {
          _realOrders = list;
          _isLoadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  final List<Map<String, dynamic>> _serviceCards = [
    {
      'title': 'Wash & Fold',
      'price': 'From ₹49',
      'category': ServiceCategory.washAndFold,
      'image': 'assets/images/service_wash_fold.jpg',
      'bg': const Color(0xFFEFF6FF),
      'tint': const Color(0xFF2563EB),
      'badge': 'POPULAR',
      'icon': Icons.dry_cleaning_outlined,
    },
    {
      'title': 'Wash & Iron',
      'price': 'From ₹69',
      'category': ServiceCategory.washAndIron,
      'image': 'assets/images/service_wash_iron.jpg',
      'bg': const Color(0xFFECFDF5),
      'tint': const Color(0xFF059669),
      'badge': 'BEST VALUE',
      'icon': Icons.iron_rounded,
    },
    {
      'title': 'Steam Iron',
      'price': 'From ₹39',
      'category': ServiceCategory.steamIron,
      'image': 'assets/images/service_steam_iron.jpg',
      'bg': const Color(0xFFFEF3C7),
      'tint': const Color(0xFFD97706),
      'badge': 'EXPRESS',
      'icon': Icons.sanitizer_outlined,
    },
    {
      'title': 'Dry Cleaning',
      'price': 'From ₹149',
      'category': ServiceCategory.dryCleaning,
      'image': 'assets/images/service_dry_clean.png',
      'bg': const Color(0xFFFDF2F8),
      'tint': const Color(0xFFDB2777),
      'badge': 'PREMIUM',
      'icon': Icons.checkroom_rounded,
    },
    {
      'title': 'Shoe Cleaning',
      'price': 'From ₹199',
      'category': ServiceCategory.shoeCleaning,
      'image': 'assets/images/service_shoe_clean.png',
      'bg': const Color(0xFFE0F2FE),
      'tint': const Color(0xFF0284C7),
      'badge': 'CARE+',
      'icon': Icons.cleaning_services_rounded,
    },
    {
      'title': 'Household',
      'price': 'From ₹299',
      'category': ServiceCategory.household,
      'image': 'assets/images/service_household.png',
      'bg': const Color(0xFFF3E8FF),
      'tint': const Color(0xFF9333EA),
      'badge': 'BULKY',
      'icon': Icons.home_outlined,
    },
  ];



  void _onServiceSelected(ServiceCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelectItemsScreen(initialCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedBottomNav,
          children: [
            _buildHomeContent(),
            _buildMyOrdersContent(),
            _buildOffersContent(),
            _buildAccountContent(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedBottomNav,
          onTap: (index) {
            setState(() => _selectedBottomNav = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: const Color(0xFF94A3B8),
          elevation: 0,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_rounded),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.checklist_rounded),
              ),
              label: 'My Orders',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.confirmation_number_outlined),
              ),
              label: 'Offers',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person_outline_rounded),
              ),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 0: HOME CONTENT =================
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Store Hero Background Image with Address & Notification Bell (Exact Image 2 Adjustment)
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Store Background Image (Full width, top aligned)
              SizedBox(
                width: double.infinity,
                height: 255,
                child: Image.asset(
                  'assets/images/hero_store.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),

              // Soft top gradient for address contrast & readability
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Address Bar and Notification Button
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showLocationPermissionDialog,
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select address',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _selectedLocation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFF334155),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          PromoLaunchPopup.show(context);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Stack(
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 22,
                                ),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Overlapping White Sheet with Rounded Top Corners (Exact Image 2 Style)
          Transform.translate(
            offset: const Offset(0, -32),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting (from Image 1)
                  Text(
                    'Good Morning, ${_userName.split(' ').first}!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Let's fresh up your clothes today.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                  ),

                  if (_topActiveOrder != null) ...[
                    const SizedBox(height: 18),
                    _buildActiveOrderBanner(),
                  ],

                  const SizedBox(height: 18),

                  // Search Bar (from Image 1)
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF94A3B8),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            onSubmitted: (val) {
                              _onServiceSelected(ServiceCategory.washAndFold);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search for Dry Clean, Iron, etc...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Promo Banner Card (from Image 1)
                  GestureDetector(
                    onTap: () => PromoLaunchPopup.show(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAB308),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'FIRSTORDER',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Get 20% OFF your first\norder!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Valid on any laundry or dry clean service.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/laundry_basket.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.white.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.shopping_basket_outlined,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Choose Service Section (Task 3 with 3D Cards)
                  Text(
                    'Choose Service',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3 Columns x 2 Rows 3D Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _serviceCards.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      final card = _serviceCards[index];
                      return _build3DServiceCard(card);
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DServiceCard(Map<String, dynamic> card) {
    final imagePath = card['image'] as String?;
    final title = card['title'] as String;
    final price = card['price'] as String;
    final category = card['category'] as ServiceCategory;
    final tint = card['tint'] as Color? ?? AppColors.primary;
    final bg = card['bg'] as Color? ?? const Color(0xFFEFF6FF);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onServiceSelected(category),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Medium 3D Artwork
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imagePath != null
                        ? Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: bg,
                              child: Icon(
                                card['icon'] as IconData? ?? Icons.local_laundry_service,
                                color: tint,
                                size: 34,
                              ),
                            ),
                          )
                        : Container(
                            color: bg,
                            child: Icon(
                              card['icon'] as IconData? ?? Icons.local_laundry_service,
                              color: tint,
                              size: 34,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 6),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 3),

                // Price Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrderBanner() {
    final rawNumber = _topActiveOrder!['orderNumber']?.toString() ?? '100001';
    final cleanNumber = rawNumber
        .replaceAll('#', '')
        .replaceAll('YD-', '')
        .replaceAll('YD', '')
        .replaceAll('-', '')
        .trim();
    final statusText = _topActiveOrder!['statusLabel']?.toString() ?? 'Processing at facility';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackOrderScreen(
              orderId: '#YD-$cleanNumber',
              rawOrderId: _topActiveOrder!['id']?.toString(),
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_laundry_service_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ACTIVE ORDER #YD-$cleanNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE2C07D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Track',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: MY ORDERS =================
  Widget _buildMyOrdersContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchOrdersByFilter(_selectedOrderFilter);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Orders',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  onPressed: () => _fetchOrdersByFilter(_selectedOrderFilter),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter Segment Pills: Active, Completed, Cancelled
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildOrderFilterChip('Active', 0),
                  const SizedBox(width: 10),
                  _buildOrderFilterChip('Completed', 1),
                  const SizedBox(width: 10),
                  _buildOrderFilterChip('Cancelled', 2),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoadingOrders)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_realOrders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: Color(0xFF94A3B8),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Orders Found',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedOrderFilter == 0
                          ? 'You have no active orders in progress.'
                          : _selectedOrderFilter == 1
                              ? 'You have no completed orders yet.'
                              : 'You have no cancelled orders.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedBottomNav = 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Book Laundry Now',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._realOrders.map((order) {
                final rawId = order['id']?.toString() ?? '';
                final rawNumber = order['orderNumber']?.toString() ?? rawId;
                final cleanNumber = rawNumber
                    .replaceAll('#', '')
                    .replaceAll('YD-', '')
                    .replaceAll('YD', '')
                    .replaceAll('-', '')
                    .trim();
                final orderNum = cleanNumber.isNotEmpty
                    ? '#YD-$cleanNumber'
                    : (rawId.length > 8 ? '#YD-${rawId.substring(0, 8)}' : '#YD-$rawId');
                final status = (order['status']?.toString() ?? 'PLANNED').toUpperCase();
                final createdAt = order['createdAt']?.toString() ?? '';
                String dateDisplay = 'Recent';
                if (createdAt.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(createdAt).toLocal();
                    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                    dateDisplay = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
                  } catch (_) {
                    dateDisplay = createdAt.split('T').first;
                  }
                }

                Color badgeBg = const Color(0xFFEFF6FF);
                Color badgeText = AppColors.primary;
                if (status == 'DELIVERED' || status == 'COMPLETED') {
                  badgeBg = const Color(0xFFECFDF5);
                  badgeText = const Color(0xFF059669);
                } else if (status == 'CANCELLED') {
                  badgeBg = const Color(0xFFFEF2F2);
                  badgeText = const Color(0xFFDC2626);
                }

                final pricing = (order['pricing'] is Map) ? (order['pricing'] as Map<String, dynamic>) : null;
                final subtotalRaw = pricing?['subtotal'] ?? order['subtotal'];
                final discountRaw = pricing?['discount'] ?? order['discount'];
                final totalRaw = pricing?['total'] ??
                    order['amount'] ??
                    order['finalAmount'] ??
                    order['totalAmount'] ??
                    order['total'];

                final itemsList = (order['items'] is List) ? (order['items'] as List) : [];
                final mappedItems = itemsList.map((it) {
                  final name = it['name']?.toString() ?? it['item']?.toString() ?? 'Laundry Item';
                  final service = it['serviceName']?.toString() ?? it['service']?.toString() ?? 'Care Service';
                  final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                  final unitP = (it['unitPrice'] as num?)?.toInt() ?? (it['price'] as num?)?.toInt();
                  final lineT = (it['lineTotal'] as num?)?.toInt();

                  int price = 0;
                  if (lineT != null && lineT > 0) {
                    price = lineT;
                  } else if (unitP != null && unitP > 0) {
                    price = unitP * qty;
                  } else {
                    final catalogMatch = CartManager.instance.catalog.where(
                      (c) => c.name.toLowerCase() == name.toLowerCase(),
                    );
                    if (catalogMatch.isNotEmpty) {
                      price = catalogMatch.first.price * qty;
                    }
                  }

                  return {
                    'name': name,
                    'service': service,
                    'quantity': qty,
                    'price': price,
                  };
                }).toList();

                final computedSubtotal = mappedItems.fold<int>(
                  0,
                  (sum, i) => sum + ((i['price'] as num?)?.toInt() ?? 0),
                );
                final subtotalVal = (subtotalRaw as num?)?.toInt() ??
                    (computedSubtotal > 0 ? computedSubtotal : 0);
                final discountVal = (discountRaw as num?)?.toInt() ?? 0;
                final grandTotalVal = (totalRaw as num?)?.toInt() ??
                    (subtotalVal > 0 ? (subtotalVal - discountVal) : computedSubtotal);

                final itemCount = mappedItems.fold<int>(
                  0,
                  (sum, i) => sum + ((i['quantity'] as num?)?.toInt() ?? 1),
                );
                final totalAmt = grandTotalVal.toString();

                final bool isActive = status != 'DELIVERED' && status != 'COMPLETED' && status != 'CANCELLED';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        final addrLine = order['address']?['line']?.toString() ?? '';
                        final addrCity = order['address']?['city']?.toString() ?? '';
                        final addrPin = order['address']?['pincode']?.toString() ?? '';

                        String fullAddr = addrLine;
                        if (fullAddr.isEmpty) {
                          fullAddr = [addrCity, addrPin].where((s) => s.isNotEmpty).join(', ');
                        } else {
                          if (addrCity.isNotEmpty && !fullAddr.toLowerCase().contains(addrCity.toLowerCase())) {
                            fullAddr += ', $addrCity';
                          }
                          if (addrPin.isNotEmpty && !fullAddr.contains(addrPin)) {
                            fullAddr += ' - $addrPin';
                          }
                        }

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => OrderDetailsScreen(
                              orderId: orderNum,
                              rawOrderId: rawId,
                              status: status,
                              dateSubtitle: 'Ordered on $dateDisplay',
                              deliveryAddress: fullAddr.isNotEmpty ? fullAddr : 'Doorstep Delivery',
                              items: mappedItems,
                              subtotal: subtotalVal,
                              discount: discountVal,
                              grandTotal: grandTotalVal,
                              riderName: order['rider']?['name']?.toString() ?? 'Assigned Partner',
                              rating: 5.0,
                            ),
                          ),
                        ).then((_) => _loadUserDataAndOrders());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orderNum,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateDisplay,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: badgeText,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ITEMS & QUANTITY',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$itemCount Items',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'TOTAL AMOUNT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹$totalAmt',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (isActive)
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => TrackOrderScreen(
                                          orderId: orderNum,
                                          rawOrderId: rawId,
                                        ),
                                      ),
                                    ).then((_) => _loadUserDataAndOrders());
                                  },
                                  icon: const Icon(Icons.location_on_outlined, size: 16),
                                  label: Text(
                                    'Track Live Order',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const SelectItemsScreen(
                                          initialCategory: ServiceCategory.washAndFold,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Reorder',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFilterChip(String label, int index) {
    final isSelected = _selectedOrderFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedOrderFilter = index);
        _fetchOrdersByFilter(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ================= TAB 2: OFFERS & COUPONS (SCREENSHOT 3) =================
  Widget _buildOffersContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offers & Coupons',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Refer & Earn ₹50 Blue Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refer & Earn ₹50!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Share your referral code with friends. Both get ₹50 bonus on first delivery.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                      ),
                      if (_referralCode.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _referralCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Referral code $_referralCode copied!'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Your Code: $_referralCode',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFF0F172A),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Available Coupons',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          if (_promotions.isNotEmpty)
            ..._promotions.map((p) {
              final code = p['code']?.toString() ?? 'OFFER';
              final type = p['type']?.toString() ?? 'PERCENTAGE';
              final val = (p['discountValue'] as num?)?.toInt() ?? 20;
              final badge = type == 'FREE_DELIVERY'
                  ? 'FREE DELIVERY'
                  : (type == 'PERCENTAGE' ? '$val% OFF' : '₹$val OFF');
              final desc = p['description']?.toString() ?? p['title']?.toString() ?? '';
              final until = p['validUntil'] != null
                  ? 'Expires ${p['validUntil'].toString().split('T').first}'
                  : 'Limited Time Offer';
              return _buildCouponCard(
                code: code,
                discountBadge: badge,
                description: desc,
                expiry: until,
                discountPercent: val,
              );
            })
          else ...[
            _buildCouponCard(
              code: 'FIRST20',
              discountBadge: '20% OFF',
              description: 'Get 20% off your very first laundry or dry clean order!',
              expiry: 'Active Promotion',
              discountPercent: 20,
            ),
            _buildCouponCard(
              code: 'FIRSTORDER',
              discountBadge: '20% OFF',
              description: '20% discount on first laundry order.',
              expiry: 'New Customers Only',
              discountPercent: 20,
            ),
            _buildCouponCard(
              code: 'FLAT100',
              discountBadge: '₹100 OFF',
              description: '₹100 off on dry clean orders valued above ₹499.',
              expiry: 'Special Offer',
              discountPercent: 20,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponCard({
    required String code,
    required String discountBadge,
    required String description,
    required String expiry,
    int discountPercent = 20,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFACC15),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                discountBadge,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                expiry,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: () {
                  CartManager.instance.applyCoupon(code, discountPercent: discountPercent);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Coupon $code applied to your cart!'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  'APPLY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: MY ACCOUNT (SCREENSHOT 4) =================
  Widget _buildAccountContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // User Profile Info Card
          GestureDetector(
            onTap: _showEditProfileModal,
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _userName.isNotEmpty ? _userName : 'Customer Profile',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userEmail.isNotEmpty && _userPhone.isNotEmpty
                            ? '$_userEmail • $_userPhone'
                            : (_userPhone.isNotEmpty
                                ? _userPhone
                                : (_userEmail.isNotEmpty
                                    ? _userEmail
                                    : 'Tap to update profile')),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Menu Options
          _buildAccountMenuItem(
            icon: Icons.location_on_outlined,
            title: 'My Addresses',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ManageAddressesScreen(),
                ),
              );
            },
          ),
          _buildAccountMenuItem(
            icon: Icons.payment_outlined,
            title: 'Payment Methods',
            onTap: () {
              _showInfoDialog(
                title: 'Payment Methods',
                message:
                    'Saved Payment Options:\n• UPI (${_userPhone.isNotEmpty ? _userPhone : "Customer"}@upi)\n• Cash on Delivery (Supported)',
              );
            },
          ),
          _buildAccountMenuItem(
            icon: Icons.tune_rounded,
            title: 'Order Preferences',
            onTap: () {
              _showInfoDialog(
                title: 'Order Preferences',
                message:
                    'Default Preferences:\n• Detergent: Hypoallergenic Eco\n• Iron Temperature: Fabric Safe\n• Packaging: Eco-Friendly Paper Bags',
              );
            },
          ),
          _buildAccountMenuItem(
            icon: Icons.card_giftcard_rounded,
            title: 'Refer & Earn',
            onTap: () {
              setState(() => _selectedBottomNav = 2);
            },
          ),
          _buildAccountMenuItem(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HelpSupportScreen(),
                ),
              );
            },
          ),
          _buildAccountMenuItem(
            icon: Icons.star_border_rounded,
            title: 'Rate Us',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for rating Yes Dhobi 5 Stars! ⭐⭐⭐⭐⭐'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
          _buildAccountMenuItem(
            icon: Icons.info_outline_rounded,
            title: 'About',
            onTap: () {
              _showInfoDialog(
                title: 'About Yes Dhobi',
                message:
                    'Yes Dhobi App v1.0.0\nYour trusted door-to-door fabric care & dry cleaning partner.',
              );
            },
          ),
          _buildAccountMenuItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            isDestructive: true,
            onTap: () async {
              await CustomerApiService.instance.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),

          const SizedBox(height: 24),

          // Official Brand Footer
          Center(
            child: Column(
              children: [
                const YesDhobiLogo(
                  height: 26,
                  variant: LogoVariant.navy,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pure Freshness • Doorstep Delivery\nv1.0.0',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFDC2626) : AppColors.primary;
    final textColor =
        isDestructive ? const Color(0xFFDC2626) : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDestructive
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF94A3B8),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.45,
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDetectGpsLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Detecting GPS location...'),
          ],
        ),
        duration: Duration(seconds: 4),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final geo = await LocationService.instance.getCurrentLocationAddress();
      if (!mounted) return;
      if (geo != null && geo.area.isNotEmpty) {
        setState(() {
          _selectedLocation = '📍 ${geo.area}, ${geo.city}';
        });
        CartManager.instance.setPickupAddress(
          geo.formatted,
          lat: geo.latitude,
          lng: geo.longitude,
        );

        // Auto-persist high-precision GPS address
        try {
          final savedAddr = await CustomerApiService.instance.createAddress(
            label: 'Current Location',
            line1: geo.formatted,
            city: geo.city,
            pincode: geo.pincode.isNotEmpty ? geo.pincode : '500081',
            lat: geo.latitude,
            lng: geo.longitude,
            isDefault: true,
          );
          if (savedAddr['id'] != null) {
            CartManager.instance.setSelectedAddressId(savedAddr['id'].toString());
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS Locked: ${geo.formatted}'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await _loadUserDataAndOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS not available. Showing saved address: $_selectedLocation'),
              backgroundColor: const Color(0xFF334155),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        await _loadUserDataAndOrders();
      }
    }
  }

  void _showLocationPermissionDialog() {
    if (_selectedBottomNav == -999) {
      _showAddressSelectionModal();
      _legacyAddressSelectionModal();
    }
    LocationSelectionSheet.show(
      context,
      onAddressSelected: (selectedAddress, {lat, lng}) {
        setState(() {
          _selectedLocation = selectedAddress;
        });
      },
    );
  }

  void _showAddressSelectionModal() {
    _showLocationPermissionDialog();
  }

  void _legacyAddressSelectionModal() {
    final searchCtrl = TextEditingController();
    List<GeoAddress> mapResults = [];
    bool isSearchingMap = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void doSearch(String q) async {
            if (q.trim().length < 2) {
              setModalState(() {
                mapResults = [];
                isSearchingMap = false;
              });
              return;
            }
            setModalState(() => isSearchingMap = true);
            try {
              final res = await LocationService.instance.searchPlaces(q);
              if (ctx.mounted) {
                setModalState(() {
                  mapResults = res;
                  isSearchingMap = false;
                });
              }
            } catch (_) {
              if (ctx.mounted) setModalState(() => isSearchingMap = false);
            }
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: CustomerApiService.instance.getAddresses(),
            builder: (ctx, snapshot) {
              final addrs = snapshot.data ?? [];
              return Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Delivery Location',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // REAL MAP SEARCH INPUT
                    TextField(
                      controller: searchCtrl,
                      onChanged: doSearch,
                      decoration: InputDecoration(
                        hintText: 'Search any location on real maps...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: isSearchingMap
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            : searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      doSearch('');
                                    },
                                  )
                                : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),

                    if (mapResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: mapResults.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final place = mapResults[idx];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_rounded, color: AppColors.primary, size: 18),
                              title: Text(
                                place.formatted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${place.city} (📍 ${place.latitude.toStringAsFixed(3)}, ${place.longitude.toStringAsFixed(3)})',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF64748B)),
                              ),
                              onTap: () async {
                                final area = place.area.isNotEmpty ? place.area : place.city;
                                setState(() => _selectedLocation = '📍 $area');
                                CartManager.instance.setPickupAddress(
                                  place.formatted,
                                  lat: place.latitude,
                                  lng: place.longitude,
                                );
                                Navigator.pop(context);
                                try {
                                  final newAddr = await CustomerApiService.instance.createAddress(
                                    label: area,
                                    line1: place.formatted,
                                    city: place.city,
                                    pincode: place.pincode.isNotEmpty ? place.pincode : '500081',
                                    lat: place.latitude,
                                    lng: place.longitude,
                                    isDefault: true,
                                  );
                                  if (newAddr['id'] != null) {
                                    CartManager.instance.setSelectedAddressId(newAddr['id'].toString());
                                  }
                                } catch (_) {}
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 10),

                    // GPS detect option button
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                        title: Text(
                          'Use Current Location (GPS)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        subtitle: Text(
                          'Tap to detect live GPS coordinates',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                        onTap: () {
                          Navigator.pop(context);
                          _handleDetectGpsLocation();
                        },
                      ),
                    ),

                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      'SAVED ADDRESSES',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (addrs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No saved addresses. Add an address to get started.',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: addrs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final a = addrs[index];
                            final label = a['label']?.toString() ?? 'Address';
                            final line1 = a['line1']?.toString() ?? a['street']?.toString() ?? '';
                            final city = a['city']?.toString() ?? '';
                            final pincode = a['pincode']?.toString() ?? '';
                            final isDefault = a['isDefault'] == true;
                            final lat = (a['lat'] as num?)?.toDouble();
                            final lng = (a['lng'] as num?)?.toDouble();

                            final fullParts = [line1, city, pincode].where((s) => s.isNotEmpty).toList();
                            final displaySub = fullParts.isNotEmpty ? fullParts.join(', ') : 'Delivery Address';

                            final icon = label.toLowerCase().contains('work')
                                ? Icons.work_outline_rounded
                                : Icons.home_outlined;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDefault ? AppColors.primary : const Color(0xFFE2E8F0),
                                  width: isDefault ? 1.4 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(icon, color: AppColors.primary),
                                title: Row(
                                  children: [
                                    Text(
                                      label,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    if (isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'DEFAULT',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (lat != null && lng != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'GPS',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  displaySub,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                onTap: () {
                                  final area = line1.isNotEmpty ? line1 : city;
                                  setState(() => _selectedLocation = '$label - $area');
                                  CartManager.instance.setPickupAddress(
                                    displaySub,
                                    addressId: a['id']?.toString(),
                                    lat: lat,
                                    lng: lng,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                      title: Text(
                        '+ Add & Manage Addresses',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ManageAddressesScreen(),
                          ),
                        ).then((_) => _loadUserDataAndOrders());
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: _userName);
    final emailCtrl = TextEditingController(text: _userEmail);
    final phoneCtrl = TextEditingController(text: _userPhone);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Phone Number (Verified)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameCtrl.text.trim();
                          final newEmail = emailCtrl.text.trim();
                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Name cannot be empty'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }
                          setModalState(() => isSaving = true);
                          try {
                            await CustomerApiService.instance.updateProfile(
                              name: newName,
                              email: newEmail.isNotEmpty ? newEmail : null,
                            );
                            if (mounted) {
                              setState(() {
                                _userName = newName;
                                if (newEmail.isNotEmpty) _userEmail = newEmail;
                              });
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully!'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating profile: $e'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    }
}
