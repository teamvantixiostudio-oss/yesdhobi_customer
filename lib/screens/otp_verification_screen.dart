import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/otp_field.dart';
import '../services/customer_api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String? name;
  final String? email;
  final String? initialAddress;
  final String? initialPincode;
  final String? devOtpHint;

  const OtpVerificationScreen({
    super.key,
    this.phoneNumber = '9876543000',
    this.name,
    this.email,
    this.initialAddress,
    this.initialPincode,
    this.devOtpHint,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late String _otpCode;
  bool _isLoading = false;
  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _otpCode = widget.devOtpHint ?? '';
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _countdown = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTimer {
    final seconds = _countdown.toString().padLeft(2, '0');
    return '00:$seconds';
  }

  Future<void> _handleVerify() async {
    if (_otpCode.isEmpty) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await CustomerApiService.instance.verifyOtp(
        widget.phoneNumber,
        _otpCode,
        name: widget.name,
        email: widget.email,
      );

      // If user registered with an initial delivery address, persist it with their pincode
      if (widget.initialAddress != null && widget.initialAddress!.trim().isNotEmpty) {
        try {
          final pin = (widget.initialPincode != null && widget.initialPincode!.trim().isNotEmpty)
              ? widget.initialPincode!.trim()
              : '500081';
          await CustomerApiService.instance.createAddress(
            label: 'Home',
            line1: widget.initialAddress!.trim(),
            city: 'Hyderabad',
            pincode: pin,
            isDefault: true,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        clearAllAppSnackBars(context);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        clearAllAppSnackBars(context);

        final rawMsg = e.toString().replaceAll('Exception: ', '');
        final isAccountNotFound = rawMsg.contains('Name is required') ||
            rawMsg.contains('create your account') ||
            rawMsg.contains('No account found') ||
            rawMsg.contains('not found') ||
            rawMsg.contains('register');

        if (isAccountNotFound && (widget.name == null || widget.name!.trim().isEmpty)) {
          // Dedicated friendly modal to guide user directly to register (no lingering bottom popup)
          _showAccountNotFoundDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(rawMsg),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showAccountNotFoundDialog() {
    clearAllAppSnackBars(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Account Not Registered',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'No account found with mobile number +91 ${widget.phoneNumber}.\n\nPlease register or create a new account to log in to Yes Dhobi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'Create New Account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    clearAllAppSnackBars(context);
                    Navigator.pop(ctx);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => RegisterScreen(
                          initialPhone: widget.phoneNumber,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton(
                  onPressed: () {
                    clearAllAppSnackBars(context);
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Go back to login screen to re-enter number
                  },
                  child: Text(
                    'Re-enter Mobile Number',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      clearAllAppSnackBars();
    });
  }

  Future<void> _handleResend() async {
    if (_countdown > 0) return;
    try {
      final res = await CustomerApiService.instance.requestOtp(widget.phoneNumber);
      _startCountdown();
      if (mounted) {
        final devOtp = res['devOtp']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent successfully!${devOtp != null ? " (Dev OTP: $devOtp)" : ""}'),
            backgroundColor: const Color(0xFF10B981),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Top Circular Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textPrimary,
                      size: 26,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Title
              Text(
                'Verify Code',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              RichText(
                text: TextSpan(
                  text: 'We have sent a 4-digit code to ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: widget.phoneNumber,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.devOtpHint != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Text(
                        'Demo OTP: ${widget.devOtpHint} (Pre-filled for testing)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // 4 OTP Boxes
              OtpInputField(
                length: 4,
                initialValue: _otpCode,
                onChanged: (val) {
                  setState(() {
                    _otpCode = val;
                  });
                },
                onCompleted: (val) {
                  setState(() {
                    _otpCode = val;
                  });
                  _handleVerify();
                },
              ),

              const SizedBox(height: 28),

              // Timer & Didn't receive code row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _countdown == 0 ? _handleResend : null,
                    child: Text(
                      _countdown == 0 ? 'Resend OTP' : 'Didn’t receive code?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: _countdown == 0 ? FontWeight.w700 : FontWeight.w400,
                        color: _countdown == 0 ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formattedTimer,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Verify & Continue Button
              CustomButton(
                text: 'Verify & Continue',
                isLoading: _isLoading,
                onPressed: _handleVerify,
              ),

              const SizedBox(height: 180),

              // Resend OTP via SMS
              Center(
                child: GestureDetector(
                  onTap: _countdown == 0 ? _handleResend : null,
                  child: Text(
                    'Resend OTP via SMS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _countdown == 0
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.8),
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
