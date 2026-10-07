import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/manage_addresses_screen.dart';
import '../services/customer_api_service.dart';
import '../services/location_service.dart';
import '../state/cart_manager.dart';

class LocationSelectionSheet extends StatefulWidget {
  final Function(String selectedAddress, {double? lat, double? lng}) onAddressSelected;

  const LocationSelectionSheet({
    super.key,
    required this.onAddressSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(String selectedAddress, {double? lat, double? lng}) onAddressSelected,
  }) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    if (isWide) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Center(
          child: Material(
            color: Colors.transparent,
            child: LocationSelectionSheet(
              onAddressSelected: onAddressSelected,
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: size.width > 600 ? 480 : size.width,
      ),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => LocationSelectionSheet(
        onAddressSelected: onAddressSelected,
      ),
    );
  }

  @override
  State<LocationSelectionSheet> createState() => _LocationSelectionSheetState();
}

class _LocationSelectionSheetState extends State<LocationSelectionSheet> {
  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoadingAddresses = true;
  bool _isEnablingGps = false;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<GeoAddress> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final list = await CustomerApiService.instance.getAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses = list;
          _isLoadingAddresses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  Future<void> _handleEnableGps() async {
    if (_isEnablingGps) return;
    setState(() => _isEnablingGps = true);

    try {
      final geo = await LocationService.instance.getCurrentLocationAddress();
      if (!mounted) return;
      setState(() => _isEnablingGps = false);

      if (geo != null && geo.formatted.isNotEmpty) {
        final displayLabel = '📍 ${geo.area}, ${geo.city}';
        CartManager.instance.setPickupAddress(
          geo.formatted,
          lat: geo.latitude,
          lng: geo.longitude,
        );

        // Auto save to backend
        try {
          final savedAddr = await CustomerApiService.instance.createAddress(
            label: 'Current Location',
            line1: geo.formatted,
            city: geo.city.isNotEmpty ? geo.city : 'Hyderabad',
            pincode: (geo.pincode.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(geo.pincode))
                ? geo.pincode
                : '500081',
            lat: geo.latitude,
            lng: geo.longitude,
            isDefault: true,
          );
          if (savedAddr['id'] != null) {
            CartManager.instance.setSelectedAddressId(savedAddr['id'].toString());
          }
        } catch (_) {}

        widget.onAddressSelected(displayLabel, lat: geo.latitude, lng: geo.longitude);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS locked: ${geo.area}, ${geo.city}'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access GPS. Please check location permissions or search below.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEnablingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final biasLat = CartManager.instance.pickupLat ?? 17.3850;
        final biasLng = CartManager.instance.pickupLng ?? 78.4867;
        final results = await LocationService.instance.searchPlaces(
          trimmed,
          biasLat: biasLat,
          biasLng: biasLng,
        );
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  void _selectSearchResult(GeoAddress place) async {
    final display = place.formatted;
    CartManager.instance.setPickupAddress(
      display,
      lat: place.latitude,
      lng: place.longitude,
    );

    // Save as recent address
    try {
      final pin = (place.pincode.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(place.pincode))
          ? place.pincode
          : '500081';
      final saved = await CustomerApiService.instance.createAddress(
        label: place.area.isNotEmpty ? place.area : 'Searched Location',
        line1: place.formatted,
        city: place.city.isNotEmpty ? place.city : 'Hyderabad',
        pincode: pin,
        lat: place.latitude,
        lng: place.longitude,
        isDefault: false,
      );
      if (saved['id'] != null) {
        CartManager.instance.setSelectedAddressId(saved['id'].toString());
      }
    } catch (_) {}

    widget.onAddressSelected(display, lat: place.latitude, lng: place.longitude);
    if (mounted) Navigator.pop(context);
  }

  void _selectSavedAddress(Map<String, dynamic> addr) {
    final label = addr['label']?.toString() ?? 'Home';
    final line1 = addr['line1']?.toString() ?? addr['street']?.toString() ?? '';
    final city = addr['city']?.toString() ?? 'Hyderabad';
    final full = line1.isNotEmpty ? '$line1, $city' : city;
    final lat = (addr['lat'] as num?)?.toDouble();
    final lng = (addr['lng'] as num?)?.toDouble();

    CartManager.instance.setPickupAddress(
      full,
      addressId: addr['id']?.toString(),
      lat: lat,
      lng: lng,
    );

    widget.onAddressSelected('$label - $full', lat: lat, lng: lng);
    Navigator.pop(context);
  }

  IconData _getIconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('work') || l.contains('office')) {
      return Icons.work_outline_rounded;
    } else if (l.contains('home')) {
      return Icons.home_outlined;
    }
    return Icons.location_on_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isWide = size.width > 600;
    final sheetHeight = isWide ? 620.0 : size.height * 0.82;

    return Container(
      width: isWide ? 480 : size.width,
      height: sheetHeight,
      constraints: BoxConstraints(
        maxWidth: isWide ? 480 : size.width,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: isWide
            ? BorderRadius.circular(24)
            : const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP CARD: "Device location not enabled" + [Enable] Action Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Red location icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.location_off_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Title & Subtitle with guaranteed horizontal flex
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Device location not enabled',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Enable your device location for a better experience',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Red "Enable" button spanning full card width
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _isEnablingGps ? null : _handleEnableGps,
                            icon: _isEnablingGps
                                ? const SizedBox.shrink()
                                : const Icon(Icons.my_location_rounded, size: 18),
                            label: _isEnablingGps
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Enable Device Location',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                    const SizedBox(height: 24),

                    // 2. MIDDLE SECTION: "Select a saved address" + [See all]
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select a saved address',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ManageAddressesScreen()),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Text(
                              'See all',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingAddresses)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    else if (_savedAddresses.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Text(
                          'No saved addresses yet. Enable GPS or search below to add your home/work address.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      )
                    else
                      ..._savedAddresses.take(3).map((addr) {
                        final label = addr['label']?.toString() ?? 'Home';
                        final line1 = addr['line1']?.toString() ?? addr['street']?.toString() ?? '';
                        final city = addr['city']?.toString() ?? 'Hyderabad';
                        final subtitle = line1.isNotEmpty ? '$line1, $city' : city;

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            onTap: () => _selectSavedAddress(addr),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getIconForLabel(label),
                                color: const Color(0xFF0F172A),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 14),

                    // 3. BOTTOM SECTION: "Search location manually"
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search location manually',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFFEF4444),
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : (_isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                                      ),
                                    )
                                  : null),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),

                    // Exact typed address quick-action card (Task 3: Guarantees user can pick their exact typed address)
                    if (_searchController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Use: "${_searchController.text.trim()}"',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E40AF),
                            ),
                          ),
                          subtitle: Text(
                            'Deliver to this exact entered address',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                          onTap: () {
                            final q = _searchController.text.trim();
                            final lat = CartManager.instance.pickupLat ?? 17.3850;
                            final lng = CartManager.instance.pickupLng ?? 78.4867;
                            _selectSearchResult(GeoAddress(
                              latitude: lat,
                              longitude: lng,
                              area: q,
                              city: 'Hyderabad',
                              pincode: '500081',
                              formatted: q.toLowerCase().contains('hyderabad') ? q : '$q, Hyderabad',
                            ));
                          },
                        ),
                      ),
                    ],

                    // Real-time Places Search Results
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                              title: Text(
                                item.area.isNotEmpty ? item.area : item.formatted,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                item.formatted,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              onTap: () => _selectSearchResult(item),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Manual full address entry shortcut button
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManageAddressesScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit_location_alt_outlined, size: 18, color: Color(0xFF64748B)),
                      label: Text(
                        'Enter flat / building number manually',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}
