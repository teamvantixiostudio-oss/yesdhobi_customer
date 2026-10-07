import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/customer_api_service.dart';
import '../state/cart_manager.dart';
import '../theme/app_theme.dart';
import 'track_order_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String? rawOrderId;
  final String status;
  final String dateSubtitle;
  final List<Map<String, dynamic>> items;
  final int subtotal;
  final int discount;
  final int grandTotal;
  final String deliveryAddress;
  final String riderName;
  final double rating;

  const OrderDetailsScreen({
    super.key,
    this.orderId = '#YD-100001',
    this.rawOrderId,
    this.status = 'PENDING_PICKUP',
    this.dateSubtitle = '',
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.grandTotal = 0,
    this.deliveryAddress = 'Doorstep Delivery',
    this.riderName = 'Assigned Partner',
    this.rating = 5.0,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late String _status;
  late String _dateSubtitle;
  late String _deliveryAddress;
  late String _riderName;
  late double _rating;
  late List<Map<String, dynamic>> _items;
  late int _subtotal;
  late int _discount;
  late int _grandTotal;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _deliveryAddress = widget.deliveryAddress;
    _riderName = widget.riderName;
    _rating = widget.rating;
    _discount = widget.discount;

    // 1. Sanitize items and ensure individual prices are NEVER zero
    _items = _sanitizeItems(widget.items);

    // 2. Sanitize subtotal and grand total so bill is NEVER zero
    final computedSubtotal = _items.fold<int>(
      0,
      (sum, i) => sum + ((i['price'] as num?)?.toInt() ?? 0),
    );
    _subtotal = widget.subtotal > 0 ? widget.subtotal : computedSubtotal;
    _grandTotal = widget.grandTotal > 0
        ? widget.grandTotal
        : (_subtotal > 0 ? (_subtotal - _discount) : computedSubtotal);

    // 3. Sanitize date subtitle dynamically
    if (widget.dateSubtitle.isNotEmpty && !widget.dateSubtitle.contains('18 Oct 2026')) {
      _dateSubtitle = widget.dateSubtitle;
    } else {
      final now = DateTime.now();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      _dateSubtitle = 'Ordered on ${now.day} ${months[now.month - 1]} ${now.year}';
    }

    // 4. Load live order details if rawOrderId is provided
    if (widget.rawOrderId != null && widget.rawOrderId!.isNotEmpty) {
      _fetchLiveOrder();
    }
  }

  String get cleanOrderId {
    final clean = widget.orderId
        .replaceAll('YD-YD-', 'YD-')
        .replaceAll('#YD-YD-', '#YD-')
        .replaceAll('##', '#')
        .trim();
    if (clean.startsWith('#')) return clean;
    return '#$clean';
  }

  List<Map<String, dynamic>> _sanitizeItems(List<Map<String, dynamic>> source) {
    if (source.isEmpty) return [];
    return source.map((it) {
      final name = it['name']?.toString() ?? it['item']?.toString() ?? 'Laundry Item';
      final service = it['serviceName']?.toString() ?? it['service']?.toString() ?? 'Care Service';
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      int price = (it['price'] as num?)?.toInt() ?? (it['lineTotal'] as num?)?.toInt() ?? 0;

      if (price <= 0) {
        final unitPrice = (it['unitPrice'] as num?)?.toInt();
        if (unitPrice != null && unitPrice > 0) {
          price = unitPrice * qty;
        } else {
          // Look up price from local catalog
          final matches = CartManager.instance.catalog.where(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
          );
          if (matches.isNotEmpty) {
            price = matches.first.price * qty;
          }
        }
      }

      return {
        'name': name,
        'service': service,
        'quantity': qty,
        'price': price,
      };
    }).toList();
  }

  Future<void> _fetchLiveOrder() async {
    try {
      final order = await CustomerApiService.instance.getOrderById(widget.rawOrderId!);
      if (!mounted) return;

      final pricing = (order['pricing'] is Map) ? (order['pricing'] as Map<String, dynamic>) : null;
      final subtotalRaw = pricing?['subtotal'] ?? order['subtotal'];
      final discountRaw = pricing?['discount'] ?? order['discount'];
      final totalRaw = pricing?['total'] ??
          order['amount'] ??
          order['finalAmount'] ??
          order['totalAmount'] ??
          order['total'];

      final itemsRaw = (order['items'] is List) ? (order['items'] as List) : [];
      final freshItems = itemsRaw.isNotEmpty
          ? _sanitizeItems(itemsRaw.cast<Map<String, dynamic>>())
          : _items;

      final computed = freshItems.fold<int>(
        0,
        (sum, i) => sum + ((i['price'] as num?)?.toInt() ?? 0),
      );
      final sub = (subtotalRaw as num?)?.toInt() ?? (computed > 0 ? computed : _subtotal);
      final disc = (discountRaw as num?)?.toInt() ?? _discount;
      final grand = (totalRaw as num?)?.toInt() ?? (sub > 0 ? (sub - disc) : _grandTotal);

      setState(() {
        if (order['status'] != null) _status = order['status'].toString().toUpperCase();
        if (order['rider']?['name'] != null) _riderName = order['rider']['name'].toString();
        _items = freshItems;
        _subtotal = sub;
        _discount = disc;
        _grandTotal = grand;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDelivered = _status.toUpperCase() == 'DELIVERED';
    final isCancelled = _status.toUpperCase() == 'CANCELLED';

    final badgeBg = isDelivered
        ? const Color(0xFFECFDF5)
        : isCancelled
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFEFF6FF);

    final badgeTextColor = isDelivered
        ? const Color(0xFF059669)
        : isCancelled
            ? const Color(0xFFDC2626)
            : AppColors.primary;

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
          'Order Details',
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
            // 1. Order ID Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: $cleanOrderId',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
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
                          _status,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: badgeTextColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dateSubtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. Items Breakdown Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items Breakdown',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Standard Laundry Wash & Care',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    )
                  else
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: '${item['name']} (${item['service']}) ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'x${item['quantity']}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${item['price']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Bill Details Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBillRow(
                    label: 'Subtotal',
                    value: '₹$_subtotal',
                  ),
                  const SizedBox(height: 10),
                  _buildBillRow(
                    label: 'Delivery Partner Fee',
                    value: 'FREE',
                    valueColor: const Color(0xFF059669),
                  ),
                  const SizedBox(height: 10),
                  _buildBillRow(
                    label: 'Promo Discount',
                    value: '-₹$_discount',
                    valueColor: const Color(0xFF059669),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Grand Total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '₹$_grandTotal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4. Delivery Address Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Address',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _deliveryAddress,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 5. Your Rating Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR RATING',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivered by $_riderName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _rating.toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (!isDelivered && !isCancelled) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.navigation_outlined, size: 20),
                  label: Text(
                    'Track Live Order',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackOrderScreen(
                          orderId: cleanOrderId,
                          rawOrderId: widget.rawOrderId,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 6. Download Invoice Button
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final targetId = widget.rawOrderId ??
                        widget.orderId.replaceAll('#', '').replaceAll('YD-', '');
                    Map<String, dynamic>? invoiceData;
                    try {
                      invoiceData = await CustomerApiService.instance.getOrderInvoice(targetId);
                    } catch (_) {}

                    final invNum = invoiceData?['invoiceNumber']?.toString() ?? 'INV-$cleanOrderId';
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tax Invoice',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice No: $invNum',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Order Reference: $cleanOrderId',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Grand Total: ₹$_grandTotal',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Status: ${_status == 'DELIVERED' ? 'PAID' : 'PENDING ON DELIVERY'}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Close',
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
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Download Invoice',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }

  Widget _buildBillRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
