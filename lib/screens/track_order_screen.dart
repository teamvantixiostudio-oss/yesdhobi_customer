import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/customer_api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;
  final String? rawOrderId;
  final String estimatedDelivery;

  const TrackOrderScreen({
    super.key,
    this.orderId = '#YD-892740',
    this.rawOrderId,
    this.estimatedDelivery = 'Tomorrow • By 6:00 PM',
  });

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  bool _isLoading = true;
  String _eta = '';
  String _statusLabel = 'Order Placed';
  List<Map<String, dynamic>> _steps = [];
  Map<String, dynamic>? _rider;
  String? _pickupOtp;
  String? _deliveryOtp;
  String _statusCode = 'PENDING_PICKUP';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _eta = widget.estimatedDelivery;
    _fetchTracking();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fetchTracking();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTracking() async {
    final queryId = widget.rawOrderId ?? widget.orderId.replaceAll('#', '');
    try {
      final res = await CustomerApiService.instance.trackOrder(queryId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (res['status'] != null) {
            _statusCode = res['status'].toString().toUpperCase();
          }
          if (res['deliveryEta'] != null && res['deliveryEta'].toString().isNotEmpty) {
            _eta = res['deliveryEta'].toString();
          }
          if (res['statusLabel'] != null) {
            _statusLabel = res['statusLabel'].toString();
          }
          if (res['tracking'] is List) {
            _steps = List<Map<String, dynamic>>.from(res['tracking']);
          }
          if (res['rider'] is Map<String, dynamic>) {
            _rider = res['rider'];
          }
          if (res['otps'] is Map<String, dynamic>) {
            _pickupOtp = res['otps']['pickup']?.toString();
            _deliveryOtp = res['otps']['delivery']?.toString();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onBack(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(initialTab: 1),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => _onBack(context),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Order',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.orderId,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchTracking();
            },
          ),
        ],
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchTracking,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Estimated Delivery Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E4CEE),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.access_time_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ESTIMATED DELIVERY • $_statusLabel',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFE2C07D),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _eta,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // OTP Verification Badge (dynamically switches between Pickup and Delivery OTPs)
                        () {
                          final bool isPickupPhase = _statusCode == 'PENDING_PICKUP' || _statusCode == 'ASSIGNED';
                          final bool isDeliveryPhase = _statusCode == 'READY' || _statusCode == 'OUT_FOR_DELIVERY';
                          final String? activeOtp = isPickupPhase
                              ? _pickupOtp
                              : (isDeliveryPhase ? _deliveryOtp : null);
                          final String otpTitle = isPickupPhase ? 'Doorstep Pickup OTP' : 'Doorstep Delivery OTP';
                          final String otpSub = isPickupPhase
                              ? 'Share this code with your pickup rider at doorstep'
                              : 'Share this code with your delivery rider at handoff';

                          if (activeOtp == null || activeOtp.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shield_outlined, color: Color(0xFF16A34A)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        otpTitle,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF166534),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        otpSub,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF14532D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF16A34A)),
                                  ),
                                  child: Text(
                                    activeOtp,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF16A34A),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }(),

                        const SizedBox(height: 24),

                        // Vertical Order Progress Stepper
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: _steps.isNotEmpty
                                ? List.generate(_steps.length, (index) {
                                    final step = _steps[index];
                                    final state = step['state']?.toString() ?? 'pending';
                                    final status = state == 'done'
                                        ? _StepStatus.completed
                                        : state == 'current'
                                            ? _StepStatus.inProgress
                                            : _StepStatus.pending;

                                    return _buildStep(
                                      title: step['title']?.toString() ?? '',
                                      subtitle: step['subtitle']?.toString() ?? '',
                                      status: status,
                                      isFirst: index == 0,
                                      isLast: index == _steps.length - 1,
                                    );
                                  })
                                : [
                                    _buildStep(
                                      title: 'Order Placed',
                                      subtitle: "We've received your request",
                                      status: _StepStatus.completed,
                                      isFirst: true,
                                    ),
                                    _buildStep(
                                      title: 'Pickup Scheduled',
                                      subtitle: 'Slot confirmed',
                                      status: _StepStatus.inProgress,
                                    ),
                                    _buildStep(
                                      title: 'Rider On Way',
                                      subtitle: 'Rider heading to your address',
                                      status: _StepStatus.pending,
                                    ),
                                    _buildStep(
                                      title: 'Clothes Picked Up',
                                      subtitle: 'Pending pickup verification',
                                      status: _StepStatus.pending,
                                    ),
                                    _buildStep(
                                      title: 'Washing In Progress',
                                      subtitle: 'Processing at premium facility',
                                      status: _StepStatus.pending,
                                    ),
                                    _buildStep(
                                      title: 'Quality Check',
                                      subtitle: 'Inspecting fabric standard',
                                      status: _StepStatus.pending,
                                    ),
                                    _buildStep(
                                      title: 'Out For Delivery',
                                      subtitle: 'Fresh clothes on their way back',
                                      status: _StepStatus.pending,
                                    ),
                                    _buildStep(
                                      title: 'Delivered',
                                      subtitle: 'Doorstep delivery completed',
                                      status: _StepStatus.pending,
                                      isLast: true,
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Floating Rider Contact Card
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5FD),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _rider?['name']?.toString() ?? 'Yes Dhobi Rider',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _rider?['phone'] != null
                                      ? 'Assigned Delivery Partner (${_rider!['phone']})'
                                      : 'Dedicated Delivery Partner',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Call Action
                          GestureDetector(
                            onTap: () {
                              final phone = _rider?['phone']?.toString() ?? '1800-YES-DHOBI';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Contacting rider: $phone'),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEEF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.call_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required _StepStatus status,
    bool isFirst = false,
    bool isLast = false,
  }) {
    Color nodeColor;
    Color lineColor;
    Widget nodeChild;
    Color titleColor = AppColors.textPrimary;

    switch (status) {
      case _StepStatus.completed:
        nodeColor = const Color(0xFF10B981);
        lineColor = const Color(0xFF10B981);
        nodeChild = const Icon(Icons.check, color: Colors.white, size: 14);
        break;
      case _StepStatus.inProgress:
        nodeColor = const Color(0xFF2E4CEE);
        lineColor = const Color(0xFFE2E8F0);
        nodeChild = const SizedBox();
        titleColor = const Color(0xFF2E4CEE);
        break;
      case _StepStatus.pending:
        nodeColor = const Color(0xFFE2E8F0);
        lineColor = const Color(0xFFE2E8F0);
        nodeChild = const SizedBox();
        titleColor = const Color(0xFF475569);
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: status == _StepStatus.pending ? Colors.white : nodeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: nodeColor,
                  width: status == _StepStatus.pending ? 2 : 0,
                ),
              ),
              child: Center(child: nodeChild),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _StepStatus { completed, inProgress, pending }
