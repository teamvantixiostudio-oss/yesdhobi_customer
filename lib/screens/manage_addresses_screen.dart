import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/customer_api_service.dart';
import '../services/location_service.dart';
import '../state/cart_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';

class AddressModel {
  final String id;
  String tag;
  String line1;
  String? line2;
  String city;
  String pincode;
  double? lat;
  double? lng;
  bool isDefault;

  AddressModel({
    required this.id,
    required this.tag,
    required this.line1,
    this.line2,
    required this.city,
    required this.pincode,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  String get fullAddress {
    final parts = [line1, line2, city, pincode].where((s) => s != null && s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : 'Delivery Address';
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? '',
      tag: json['label']?.toString() ?? 'Home',
      line1: json['line1']?.toString() ?? '',
      line2: json['line2']?.toString(),
      city: json['city']?.toString() ?? 'Hyderabad',
      pincode: json['pincode']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isDefault: json['isDefault'] == true,
    );
  }
}

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  final List<AddressModel> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final data = await CustomerApiService.instance.getAddresses();
      if (mounted) {
        setState(() {
          _addresses.clear();
          _addresses.addAll(data.map((json) => AddressModel.fromJson(json)));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddEditAddressDialog({AddressModel? addressToEdit}) {
    final isEditing = addressToEdit != null;
    final tagController =
        TextEditingController(text: isEditing ? addressToEdit.tag : 'Home');
    final line1Controller =
        TextEditingController(text: isEditing ? addressToEdit.line1 : '');
    final cityController = TextEditingController(
        text: isEditing && addressToEdit.city.isNotEmpty
            ? addressToEdit.city
            : 'Hyderabad');
    final pincodeController =
        TextEditingController(text: isEditing ? addressToEdit.pincode : '');
    final searchController = TextEditingController();

    double? selectedLat = isEditing ? addressToEdit.lat : null;
    double? selectedLng = isEditing ? addressToEdit.lng : null;
    bool isDetectingGps = false;
    bool isSearching = false;
    List<GeoAddress> searchResults = [];
    Timer? debounceTimer;

    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void runSearch(String query) {
            debounceTimer?.cancel();
            if (query.trim().length < 2) {
              setDialogState(() {
                searchResults = [];
                isSearching = false;
              });
              return;
            }
            setDialogState(() => isSearching = true);
            debounceTimer = Timer(const Duration(milliseconds: 350), () async {
              try {
                final biasLat = selectedLat ?? 17.3850;
                final biasLng = selectedLng ?? 78.4867;
                final results = await LocationService.instance.searchPlaces(
                  query,
                  biasLat: biasLat,
                  biasLng: biasLng,
                );
                if (ctx.mounted) {
                  setDialogState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                }
              } catch (_) {
                if (ctx.mounted) {
                  setDialogState(() => isSearching = false);
                }
              }
            });
          }

          Future<void> detectGps() async {
            setDialogState(() {
              isDetectingGps = true;
              errorMessage = null;
            });
            try {
              final geo = await LocationService.instance.getCurrentLocationAddress();
              if (geo != null && ctx.mounted) {
                setDialogState(() {
                  selectedLat = geo.latitude;
                  selectedLng = geo.longitude;
                  line1Controller.text = geo.formatted;
                  cityController.text = geo.city;
                  pincodeController.text = geo.pincode;
                  isDetectingGps = false;
                });
              } else {
                if (ctx.mounted) {
                  setDialogState(() {
                    isDetectingGps = false;
                    errorMessage = 'Could not get device GPS. Please search your place on the map below.';
                  });
                }
              }
            } catch (_) {
              if (ctx.mounted) {
                setDialogState(() {
                  isDetectingGps = false;
                  errorMessage = 'GPS request timed out. Please enter or search on map.';
                });
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Address' : 'Add New Address',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 1. AUTO-DETECT GPS LOCATION BUTTON
                    InkWell(
                      onTap: isDetectingGps ? null : detectGps,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            if (isDetectingGps)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            else
                              const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDetectingGps ? 'Accessing Live GPS...' : 'Use Current Live GPS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Auto-detect precise coordinates from device',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. REAL MAP SEARCH BAR (AWS Places Search)
                    TextField(
                      controller: searchController,
                      onChanged: runSearch,
                      decoration: InputDecoration(
                        hintText: 'Search locality, street, or apartment...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            : searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      searchController.clear();
                                      runSearch('');
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

                    // REAL MAP SEARCH SUGGESTIONS DROPDOWN
                    if (searchResults.isNotEmpty || searchController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            if (searchController.text.trim().isNotEmpty)
                              ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 18),
                                title: Text(
                                  'Use exact building: "${searchController.text.trim()}"',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                subtitle: Text(
                                  'Keep your custom typed apartment / building name',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                onTap: () {
                                  setDialogState(() {
                                    line1Controller.text = searchController.text.trim();
                                    searchResults = [];
                                    searchController.clear();
                                  });
                                },
                              ),
                            if (searchResults.isNotEmpty && searchController.text.trim().isNotEmpty)
                              const Divider(height: 1),
                            ...searchResults.map((place) => ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(Icons.place_rounded, color: AppColors.primary, size: 18),
                              title: Text(
                                place.formatted,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${place.city}${place.pincode.isNotEmpty ? " • ${place.pincode}" : ""} (📍 ${place.latitude.toStringAsFixed(3)}, ${place.longitude.toStringAsFixed(3)})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              onTap: () {
                                setDialogState(() {
                                  selectedLat = place.latitude;
                                  selectedLng = place.longitude;
                                  final entered = searchController.text.trim();
                                  if (entered.isNotEmpty && !place.formatted.toLowerCase().contains(entered.toLowerCase())) {
                                    line1Controller.text = '$entered, ${place.formatted}';
                                  } else {
                                    line1Controller.text = place.formatted;
                                  }
                                  cityController.text = place.city;
                                  if (place.pincode.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(place.pincode)) {
                                    pincodeController.text = place.pincode;
                                  }
                                  searchResults = [];
                                  searchController.clear();
                                });
                              },
                            )),
                          ],
                        ),
                      ),
                    ],

                    // 3. MAP VERIFICATION CARD (IF COORDINATES PINNED)
                    if (selectedLat != null && selectedLng != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                LocationService.instance.getStaticMapUrl(
                                  lat: selectedLat!,
                                  lng: selectedLng!,
                                  width: 140,
                                  height: 90,
                                  zoom: 15,
                                ),
                                width: 70,
                                height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 70,
                                  height: 46,
                                  color: const Color(0xFFD1FAE5),
                                  child: const Icon(Icons.map_rounded, color: Color(0xFF059669), size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified Real Map Pin',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF065F46),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${selectedLat!.toStringAsFixed(4)}° N, ${selectedLng!.toStringAsFixed(4)}° E',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Quick Label selection
                    Row(
                      children: ['Home', 'Work', 'Other'].map((label) {
                        final isSelected = tagController.text.trim().toLowerCase() ==
                            label.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            selectedColor: const Color(0xFFEFF6FF),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFF64748B),
                            ),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() {
                                  tagController.text = label;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g. Home, Work, Other)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: line1Controller,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Flat / Building / Street Address',
                        hintText: 'e.g. Flat 302, Lake View Apts, Ramanthapur',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              hintText: 'Hyderabad',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: pincodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Pincode',
                              hintText: '500013',
                              border: OutlineInputBorder(),
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final tag = tagController.text.trim();
                        final line1 = line1Controller.text.trim();
                        final city = cityController.text.trim();
                        final pincode = pincodeController.text.trim();

                        if (tag.isEmpty) {
                          setDialogState(() => errorMessage = 'Please specify an address label');
                          return;
                        }
                        if (line1.length < 3) {
                          setDialogState(() => errorMessage = 'Street address must be at least 3 characters');
                          return;
                        }
                        if (city.length < 2) {
                          setDialogState(() => errorMessage = 'Please enter a valid city name');
                          return;
                        }
                        if (!RegExp(r'^\d{6}$').hasMatch(pincode)) {
                          setDialogState(() => errorMessage = 'Please enter a valid 6-digit Pincode');
                          return;
                        }

                        setDialogState(() {
                          errorMessage = null;
                          isSubmitting = true;
                        });

                        final sm = ScaffoldMessenger.of(context);

                        // Fallback geocode if customer typed manually without map selection
                        if (selectedLat == null || selectedLng == null) {
                          try {
                            final geocoded = await LocationService.instance.searchPlaces('$line1, $city');
                            if (geocoded.isNotEmpty) {
                              selectedLat = geocoded[0].latitude;
                              selectedLng = geocoded[0].longitude;
                            }
                          } catch (_) {}
                        }

                        try {
                          if (isEditing) {
                            await CustomerApiService.instance.updateAddress(
                              addressToEdit.id,
                              {
                                'label': tag,
                                'line1': line1,
                                'city': city,
                                'pincode': pincode,
                                'lat': ?selectedLat,
                                'lng': ?selectedLng,
                              },
                            );
                          } else {
                            final newAddr = await CustomerApiService.instance.createAddress(
                              label: tag,
                              line1: line1,
                              city: city,
                              pincode: pincode,
                              lat: selectedLat,
                              lng: selectedLng,
                              isDefault: _addresses.isEmpty,
                            );
                            final addrId = newAddr['id']?.toString();
                            CartManager.instance.setPickupAddress(
                              '$line1, $city $pincode',
                              addressId: addrId,
                              lat: selectedLat,
                              lng: selectedLng,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadAddresses();
                          if (mounted) {
                            sm.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'Address updated with map coordinates!'
                                      : 'New address pinned on real maps!',
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Update' : 'Save Address'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete "${address.tag}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await CustomerApiService.instance.deleteAddress(address.id);
      _loadAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${address.tag} address removed'),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
                size: 26,
              ),
            ),
          ),
        ),
        title: Text(
          'Manage Addresses',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                Expanded(
                  child: _addresses.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_off_outlined,
                                    size: 36,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Addresses Saved',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your home or office address to schedule quick doorstep laundry pickups.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: _addresses.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final address = _addresses[index];
                            final hasCoordinates = address.lat != null && address.lng != null;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: address.isDefault ? AppColors.primary : const Color(0xFFE2E8F0),
                                  width: address.isDefault ? 1.5 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.location_on_outlined,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              address.tag,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            if (address.isDefault) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'DEFAULT',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFF059669),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (hasCoordinates) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.check_circle_rounded, size: 10, color: AppColors.primary),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      'GPS PINNED',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _showAddEditAddressDialog(
                                          addressToEdit: address,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.edit_outlined,
                                            color: Color(0xFF64748B),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _deleteAddress(address),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Color(0xFFEF4444),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    address.fullAddress,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF64748B),
                                      height: 1.4,
                                    ),
                                  ),
                                  if (hasCoordinates) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Coordinates: ${address.lat!.toStringAsFixed(4)}° N, ${address.lng!.toStringAsFixed(4)}° E',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  color: Colors.white,
                  child: CustomButton(
                    text: '+ Add New Address',
                    onPressed: () => _showAddEditAddressDialog(),
                  ),
                ),
              ],
            ),
    );
  }
}
