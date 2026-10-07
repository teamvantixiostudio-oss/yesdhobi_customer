import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/customer_api_service.dart';
import '../state/cart_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';
import 'manage_addresses_screen.dart';
import 'order_success_screen.dart';

class SchedulePickupScreen extends StatefulWidget {
  const SchedulePickupScreen({super.key});

  @override
  State<SchedulePickupScreen> createState() => _SchedulePickupScreenState();
}

class _SchedulePickupScreenState extends State<SchedulePickupScreen> {
  final CartManager _cartManager = CartManager.instance;
  final TextEditingController _instructionsController = TextEditingController();

  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoadingAddresses = true;
  bool _isSubmitting = false;

  // 0: Instant Doorstep Pickup (15-25 Mins), 1: Today Evening (5:00 PM - 7:00 PM)
  int _selectedTimingMode = 0;

  // 0: Pay Online (UPI / GPay / Card), 1: Pay on Doorstep (Cash or UPI after weighing)
  int _selectedPaymentMethod = 0;

  final List<String> _quickInstructions = [
    '🔔 Ring doorbell',
    '📞 Call on arrival',
    '🛡️ Leave at security',
    '🚪 Don’t ring bell',
  ];

  @override
  void initState() {
    super.initState();
    _instructionsController.text = _cartManager.pickupInstructions;
    _cartManager.addListener(_onCartChanged);
    _fetchAddresses();
  }

  @override
  void dispose() {
    _cartManager.removeListener(_onCartChanged);
    _instructionsController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchAddresses() async {
    try {
      final list = await CustomerApiService.instance.getAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses = list;
          _isLoadingAddresses = false;

          // If no address selected in cart yet, select the default or first one
          if (_cartManager.selectedAddressId == null && list.isNotEmpty) {
            final def = list.firstWhere(
              (a) => a['isDefault'] == true,
              orElse: () => list.first,
            );
            final full = [def['line1'], def['line2'], def['city'], def['pincode']]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(', ');
            final lat = (def['lat'] as num?)?.toDouble();
            final lng = (def['lng'] as num?)?.toDouble();
            _cartManager.setPickupAddress(full, addressId: def['id'].toString(), lat: lat, lng: lng);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _onConfirmAndRequestPickup() async {
    // 1. Ensure user is authenticated
    if (!ApiClient.instance.isAuthenticated) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (loggedIn != true && !ApiClient.instance.isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to confirm your pickup request'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      _fetchAddresses();
    }

    setState(() => _isSubmitting = true);

    try {
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
                : 'Flat 402, Green Glen Layout, Bellandur, Outer Ring Rd',
            lat: _cartManager.pickupLat,
            lng: _cartManager.pickupLng,
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
      final todayIso = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final slotLabel = _selectedTimingMode == 0 ? 'Instant (10 Mins)' : 'Evening (5:00 PM - 7:00 PM)';

      _cartManager.setPickupDate('Instant Pickup');
      _cartManager.setPickupSlot(slotLabel);
      _cartManager.setPickupInstructions(_instructionsController.text.trim());

      // 4. Place live order via AWS backend (immediately triggers startRiderDispatch)
      final orderRes = await CustomerApiService.instance.placeOrder(
        items: itemsPayload.isNotEmpty ? itemsPayload : [{'code': 'wi_1', 'quantity': 1}],
        addressId: addressId,
        pickupDate: todayIso,
        pickupSlot: slotLabel,
        paymentMethod: _selectedPaymentMethod == 0 ? 'UPI' : 'COD',
        promoCode: _cartManager.couponApplied ? _cartManager.couponCode : null,
        notes: _instructionsController.text.trim().isNotEmpty
            ? _instructionsController.text.trim()
            : null,
      );

      final rawId = orderRes['id']?.toString() ?? '';
      final rawNumber = orderRes['orderNumber']?.toString() ?? orderRes['displayId']?.toString() ?? '100001';
      final cleanNumber = rawNumber
          .replaceAll('#', '')
          .replaceAll('YD-', '')
          .replaceAll('YD', '')
          .replaceAll('-', '')
          .trim();
      final displayId = cleanNumber.isNotEmpty ? '#YD-$cleanNumber' : '#YD-$rawId';
      final eta = orderRes['deliveryEta']?.toString() ?? '';

      _cartManager.clearCart();

      if (mounted) {
        setState(() => _isSubmitting = false);
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
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Pickup Address',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoadingAddresses)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (_savedAddresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No saved addresses found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _savedAddresses.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final a = _savedAddresses[index];
                        final full = [a['line1'], a['line2'], a['city'], a['pincode']]
                            .where((s) => s != null && s.toString().isNotEmpty)
                            .join(', ');
                        final label = a['label']?.toString() ?? 'Address';
                        final isSel = _cartManager.selectedAddressId == a['id']?.toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              label.toLowerCase() == 'home'
                                  ? Icons.home_rounded
                                  : label.toLowerCase() == 'work'
                                      ? Icons.work_rounded
                                      : Icons.location_on_rounded,
                              color: isSel ? AppColors.primary : const Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            full,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: isSel
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                              : null,
                          onTap: () {
                            final lat = (a['lat'] as num?)?.toDouble();
                            final lng = (a['lng'] as num?)?.toDouble();
                            _cartManager.setPickupAddress(full, addressId: a['id']?.toString(), lat: lat, lng: lng);
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      'Add New Address',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageAddressesScreen()),
                      );
                      _fetchAddresses();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
          'Instant Pickup',
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
            // 1. Live Instant Arrival Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'RIDERS ACTIVE NEARBY',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAB308),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '⚡ 10 MINS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Instant Doorstep Pickup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confirming booking immediately alerts the nearest rider. Your clothes will be weighed and verified right at your doorstep.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFeaturePill(Icons.flash_on_rounded, 'Instant Alert'),
                        Container(width: 1, height: 20, color: Colors.white24),
                        _buildFeaturePill(Icons.scale_outlined, 'Doorstep Weighing'),
                        Container(width: 1, height: 20, color: Colors.white24),
                        _buildFeaturePill(Icons.security_rounded, '4-Digit OTP'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Select Pickup Timing (Instant vs Today Evening)
            Text(
              'Pickup Timing',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTimingCard(
                    index: 0,
                    icon: Icons.bolt_rounded,
                    title: 'Instant Pickup',
                    subtitle: '10 Mins arrival',
                    badge: 'FASTEST',
                    badgeColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimingCard(
                    index: 1,
                    icon: Icons.schedule_rounded,
                    title: 'Today Evening',
                    subtitle: '5:00 PM – 7:00 PM',
                    badge: 'AFTER WORK',
                    badgeColor: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Pickup Address Section
            Text(
              'Pickup Location',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Home Address',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: _showAddressPicker,
                              child: Text(
                                'EDIT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cartManager.pickupAddress.isNotEmpty
                              ? _cartManager.pickupAddress
                              : 'Select or add your pickup address',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Pickup Instructions (Optional)
            Text(
              'Pickup Instructions (Optional)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickInstructions.map((chip) {
                final isSelected = _instructionsController.text.contains(chip);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_instructionsController.text.isEmpty) {
                        _instructionsController.text = chip;
                      } else if (!_instructionsController.text.contains(chip)) {
                        _instructionsController.text =
                            '${_instructionsController.text}, $chip';
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : const Color(0xFF334155),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: TextField(
                controller: _instructionsController,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Ring the doorbell, gate code, tower number...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. Select Payment Mode
            Text(
              'Select Payment Mode',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodCard(
                    index: 0,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Pay Online',
                    subtitle: 'UPI / Card / Netbanking',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentMethodCard(
                    index: 1,
                    icon: Icons.handshake_outlined,
                    title: 'Pay at Doorstep',
                    subtitle: 'Cash / UPI after weighing',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 6. Standard Turnaround Guarantee
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Standard delivery within 24–48 hours after wash & steam iron',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 7. Order & Bill Summary Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bill Summary',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_cartManager.totalItemCount} Items Added',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_cartManager.selectedItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ..._cartManager.selectedItems.map((item) {
                      final itemTotal = item.price * item.quantity;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFDBEAFE)),
                                    ),
                                    child: Text(
                                      '${item.quantity}x',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          item.category.title,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
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
                  ],
                  const Divider(color: Color(0xFFF1F5F9), height: 20),
                  _buildSummaryRow('Items Subtotal', '₹${_cartManager.subtotal}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Instant Delivery Partner Fee',
                    'FREE',
                    amountColor: const Color(0xFF16A34A),
                    isHighlight: true,
                  ),
                  if (_cartManager.couponApplied) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Promo Discount (20%)',
                      '-₹${_cartManager.discountAmount}',
                      amountColor: const Color(0xFF0D9488),
                      isHighlight: true,
                    ),
                  ],
                  const Divider(color: Color(0xFFF1F5F9), height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payable',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '₹${_cartManager.grandTotal}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 8. Confirm Pickup Button
            CustomButton(
              text: _isSubmitting
                  ? 'Requesting Nearest Rider...'
                  : 'Confirm & Request Instant Pickup (₹${_cartManager.grandTotal})',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? () {} : _onConfirmAndRequestPickup,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
  }) {
    final isSelected = _selectedTimingMode == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTimingMode = index),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                  size: 22,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedPaymentMethod == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = index),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                  size: 22,
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String amount, {
    Color? amountColor,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: amountColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
