import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/cart_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../services/api_client.dart';
import '../services/customer_api_service.dart';
import 'order_success_screen.dart';
import 'login_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  final String? isoPickupDate;

  const OrderSummaryScreen({
    super.key,
    this.isoPickupDate,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final CartManager _cartManager = CartManager.instance;
  int _selectedPaymentMethod = 0; // 0: Pay Online (UPI / Card), 1: Cash on Delivery
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _cartManager.addListener(_onCartUpdated);
  }

  @override
  void dispose() {
    _cartManager.removeListener(_onCartUpdated);
    super.dispose();
  }

  void _onCartUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _onPlaceOrder() async {
    setState(() => _isPlacingOrder = true);

    try {
      // 1. Ensure authenticated
      if (!ApiClient.instance.isAuthenticated) {
        setState(() => _isPlacingOrder = false);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        if (!ApiClient.instance.isAuthenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please log in to confirm your booking'),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        setState(() => _isPlacingOrder = true);
      }

      // 2. Resolve address
      String addressId = _cartManager.selectedAddressId ?? '';
      if (addressId.isEmpty) {
        final addresses = await CustomerApiService.instance.getAddresses();
        if (addresses.isNotEmpty) {
          addressId = addresses[0]['id'].toString();
        } else {
          final newAddr = await CustomerApiService.instance.createAddress(
            label: 'Home',
            line1: _cartManager.pickupAddress.isNotEmpty
                ? _cartManager.pickupAddress
                : 'Flat 204, Green Heights, Hi-Tech City',
            isDefault: true,
          );
          addressId = newAddr['id'].toString();
        }
      }

      // 3. Prepare items payload
      final itemsPayload = _cartManager.selectedItems.map((item) => {
        'code': item.id,
        'quantity': item.quantity,
      }).toList();

      final now = DateTime.now();
      final pickupDate = widget.isoPickupDate ??
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // 4. Call live AWS backend
      final orderRes = await CustomerApiService.instance.placeOrder(
        items: itemsPayload.isNotEmpty ? itemsPayload : [{'code': 'wi_1', 'quantity': 1}],
        addressId: addressId,
        pickupDate: pickupDate,
        pickupSlot: _cartManager.selectedSlot.isNotEmpty ? _cartManager.selectedSlot : '6-8 PM',
        paymentMethod: _selectedPaymentMethod == 0 ? 'UPI' : 'COD',
        promoCode: _cartManager.couponApplied ? _cartManager.couponCode : null,
        notes: _cartManager.pickupInstructions.isNotEmpty ? _cartManager.pickupInstructions : null,
      );

      final rawId = orderRes['id']?.toString() ?? '';
      final displayId = orderRes['orderNumber'] != null
          ? '#YD-${orderRes['orderNumber']}'
          : (orderRes['displayId']?.toString() ?? '#YD-100001');
      final eta = orderRes['deliveryEta']?.toString() ?? 'Tomorrow • By 6:00 PM';

      _cartManager.clearCart();

      if (mounted) {
        setState(() => _isPlacingOrder = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              orderId: displayId,
              rawOrderId: rawId,
              estimatedDelivery: eta,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItems = _cartManager.selectedItems;

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
          'Order Summary',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Items Breakdown
                  if (selectedItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No items in basket',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  else
                    ...selectedItems.map((item) {
                      final itemTotal = item.price * item.quantity;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: '${item.name} (${item.category.title}) ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'x${item.quantity}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹$itemTotal',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const Divider(color: Color(0xFFF1F5F9), height: 24),

                  // Subtotal
                  _buildSummaryRow('Subtotal', '₹${_cartManager.subtotal}'),

                  const SizedBox(height: 8),

                  // Delivery Partner Fee
                  _buildSummaryRow(
                    'Delivery Partner Fee',
                    'FREE',
                    amountColor: const Color(0xFF16A34A),
                    isHighlight: true,
                  ),

                  const SizedBox(height: 8),

                  // Promo Discount
                  if (_cartManager.couponApplied)
                    _buildSummaryRow(
                      'Promo Discount (20%)',
                      '-₹${_cartManager.discountAmount}',
                      amountColor: const Color(0xFF0D9488),
                      isHighlight: true,
                    ),

                  const Divider(color: Color(0xFFF1F5F9), height: 24),

                  // Grand Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Grand Total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '₹${_cartManager.grandTotal}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Coupon Applied Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _cartManager.couponApplied
                                ? '${_cartManager.couponCode} Applied!'
                                : 'Have a coupon code?',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _cartManager.toggleCoupon(),
                    child: Text(
                      _cartManager.couponApplied ? 'REMOVE' : 'APPLY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section: Select Payment Method
            Text(
              'Select Payment Method',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // Online Payment Option
            GestureDetector(
              onTap: () => setState(() => _selectedPaymentMethod = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedPaymentMethod == 0
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedPaymentMethod == 0
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                      ),
                      child: _selectedPaymentMethod == 0
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₹',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pay Online (UPI / Card)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Cash on Delivery Option
            GestureDetector(
              onTap: () => setState(() => _selectedPaymentMethod = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedPaymentMethod == 1
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedPaymentMethod == 1
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                      ),
                      child: _selectedPaymentMethod == 1
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.money_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pay on Delivery / Pickup (Cash or UPI)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Place Order Button
            CustomButton(
              text: 'Place Order • ₹${_cartManager.grandTotal}',
              isLoading: _isPlacingOrder,
              onPressed: _onPlaceOrder,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String amount, {
    Color? amountColor,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            color: amountColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
