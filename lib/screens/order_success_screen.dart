import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/cart_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';
import 'track_order_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String? rawOrderId;
  final String estimatedDelivery;

  const OrderSuccessScreen({
    super.key,
    this.orderId = '#YD-100001',
    this.rawOrderId,
    this.estimatedDelivery = '',
  });

  String get cleanOrderId {
    final clean = orderId
        .replaceAll('YD-YD-', 'YD-')
        .replaceAll('#YD-YD-', '#YD-')
        .trim();
    if (clean.startsWith('#')) return clean;
    return '#$clean';
  }

  String _formatDeliveryDate(String etaRaw) {
    final now = DateTime.now();
    DateTime target = now.add(const Duration(hours: 24));

    if (etaRaw.contains('T') || RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(etaRaw)) {
      try {
        target = DateTime.parse(etaRaw).toLocal();
      } catch (_) {}
    } else if (etaRaw.trim().isNotEmpty &&
        !etaRaw.toLowerCase().contains('oct 25') &&
        !etaRaw.toLowerCase().contains('standard delivery')) {
      final parts = etaRaw.split('\n');
      if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
        return parts[0].trim();
      }
    }

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final diffDays = target.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (diffDays <= 1) {
      return 'Tomorrow, ${target.day} ${months[target.month - 1]}';
    } else if (diffDays == 2) {
      return 'In 2 Days, ${target.day} ${months[target.month - 1]}';
    } else {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[target.weekday - 1]}, ${target.day} ${months[target.month - 1]}';
    }
  }

  String _formatDeliveryTime(String etaRaw) {
    if (etaRaw.contains('By ') || etaRaw.contains('PM') || etaRaw.contains('AM')) {
      final match = RegExp(
        r'(By\s+\d{1,2}:\d{2}\s+(?:AM|PM)|\d{1,2}:\d{2}\s+(?:AM|PM))',
        caseSensitive: false,
      ).firstMatch(etaRaw);
      if (match != null) {
        final text = match.group(0)!;
        return text.startsWith('By ') ? text : 'By $text';
      }
    }
    return 'By 6:00 PM';
  }

  void _onBackToHome(BuildContext context) {
    CartManager.instance.clearCart();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Green Circle with Checkmark
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 3.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Color(0xFF059669),
                    size: 52,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title
              Text(
                'Order Placed Successfully!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                'Thank you for choosing Yes Dhobi. Your laundry is in safe hands.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 36),

              // Order Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Order ID Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order ID',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          cleanOrderId,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: Color(0xFFF1F5F9), height: 28),

                    // Estimated Delivery Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Delivery',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDeliveryDate(estimatedDelivery),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDeliveryTime(estimatedDelivery),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Rider Arrival Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Rider will arrive for instant pickup within 10 mins.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Track Order Button
              CustomButton(
                text: 'Track Order',
                onPressed: () {
                  CartManager.instance.clearCart();
                  final deliveryLabel = '${_formatDeliveryDate(estimatedDelivery)} • ${_formatDeliveryTime(estimatedDelivery)}';
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TrackOrderScreen(
                        orderId: cleanOrderId,
                        rawOrderId: rawOrderId,
                        estimatedDelivery: deliveryLabel,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // Back to Home Link
              GestureDetector(
                onTap: () => _onBackToHome(context),
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
