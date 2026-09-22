import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/otp_field.dart';
import '../services/customer_api_service.dart';
import 'home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    this.phoneNumber = '9876543000',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _otpCode = '1234';
  bool _isLoading = false;
  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
      await CustomerApiService.instance.verifyOtp(widget.phoneNumber, _otpCode);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleResend() async {
    if (_countdown > 0) return;
    try {
      await CustomerApiService.instance.requestOtp(widget.phoneNumber);
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully (Test OTP: 1234)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
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

              const SizedBox(height: 36),

              // 4 OTP Boxes matching screenshot (pre-filled with 4, 8, 2)
              OtpInputField(
                length: 4,
                initialValue: '1234',
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
