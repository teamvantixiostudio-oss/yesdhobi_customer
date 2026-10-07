import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SocialAuthButton extends StatelessWidget {
  final String text;
  final Widget icon;
  final VoidCallback onPressed;
  final bool fullWidth;

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: buttonContent,
      );
    }

    return Expanded(
      child: SizedBox(
        height: 52,
        child: buttonContent,
      ),
    );
  }
}

/// Official Real Google 4-Color Logo
class SocialGoogleIcon extends StatelessWidget {
  final double size;
  const SocialGoogleIcon({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Official Apple Icon
class SocialAppleIcon extends StatelessWidget {
  final double size;
  const SocialAppleIcon({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.apple,
      size: size + 2,
      color: Colors.black,
    );
  }
}

/// Alias for backward compatibility
class SocialPlayGoogleIcon extends StatelessWidget {
  final double size;
  const SocialPlayGoogleIcon({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return SocialGoogleIcon(size: size);
  }
}
