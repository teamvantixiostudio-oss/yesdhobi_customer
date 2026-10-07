import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/laundry_item.dart';
import '../state/cart_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/laundry_item_icon.dart';
import 'schedule_pickup_screen.dart';

class SelectItemsScreen extends StatefulWidget {
  final ServiceCategory initialCategory;

  const SelectItemsScreen({
    super.key,
    this.initialCategory = ServiceCategory.washAndFold,
  });

  @override
  State<SelectItemsScreen> createState() => _SelectItemsScreenState();
}

class _SelectItemsScreenState extends State<SelectItemsScreen> {
  late ServiceCategory _selectedCategory;
  final CartManager _cartManager = CartManager.instance;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _cartManager.addListener(_onCartChanged);
    // safety net: the app may have been resumed straight onto this screen
    _cartManager.loadCatalogFromServer();
  }

  @override
  void dispose() {
    _cartManager.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  String _getCategoryAsset(ServiceCategory cat) {
    switch (cat) {
      case ServiceCategory.washAndFold:
        return 'assets/images/service_wash_fold.jpg';
      case ServiceCategory.washAndIron:
        return 'assets/images/service_wash_iron.jpg';
      case ServiceCategory.steamIron:
        return 'assets/images/service_steam_iron.jpg';
      case ServiceCategory.dryCleaning:
        return 'assets/images/service_dry_clean.png';
      case ServiceCategory.shoeCleaning:
        return 'assets/images/service_shoe_clean.png';
      case ServiceCategory.household:
        return 'assets/images/service_household.png';
    }
  }

  IconData _getCategoryIcon(ServiceCategory cat) {
    switch (cat) {
      case ServiceCategory.washAndFold:
        return Icons.local_laundry_service_rounded;
      case ServiceCategory.washAndIron:
        return Icons.iron_rounded;
      case ServiceCategory.steamIron:
        return Icons.sanitizer_rounded;
      case ServiceCategory.dryCleaning:
        return Icons.checkroom_rounded;
      case ServiceCategory.shoeCleaning:
        return Icons.cleaning_services_rounded;
      case ServiceCategory.household:
        return Icons.home_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _cartManager.catalog
        .where((item) => item.category == _selectedCategory)
        .toList();

    final hasBasketItems = _cartManager.totalItemCount > 0;

    return Scaffold(
      backgroundColor: Colors.white,
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
          'Select Items',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),

          // Horizontal Service Filter Tabs with Medium Service Icons
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ServiceCategory.values.length,
              itemBuilder: (context, index) {
                final category = ServiceCategory.values[index];
                final isSelected = category == _selectedCategory;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF4FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Medium Service Icon / Artwork
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            _getCategoryAsset(category),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Icon(
                              _getCategoryIcon(category),
                              size: 18,
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: filteredItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildItemCard(item);
              },
            ),
          ),

          // Bottom Sticky Basket View (when items are added)
          if (hasBasketItems) _buildStickyBasketBar(),
        ],
      ),
    );
  }

  Widget _buildItemCard(LaundryItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Box
          LaundryItemIcon(
            iconKey: item.iconKey,
            size: 44,
          ),
          const SizedBox(width: 14),

          // Item Name and Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    text: '${item.category.title} • ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                    children: [
                      TextSpan(
                        text: '₹${item.price}/${item.unit}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quantity Stepper or Add Button
          if (item.quantity == 0)
            SizedBox(
              height: 36,
              width: 76,
              child: OutlinedButton(
                onPressed: () => _cartManager.incrementItem(item.id),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _cartManager.decrementItem(item.id),
                    child: Container(
                      width: 32,
                      height: 36,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.remove_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${item.quantity}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _cartManager.incrementItem(item.id),
                    child: Container(
                      width: 32,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyBasketBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        elevation: 6,
        shadowColor: AppColors.primary.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SchedulePickupScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_cartManager.totalItemCount} ITEMS ADDED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        text: '₹${_cartManager.subtotal} ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: 'plus taxes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'View Basket',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
