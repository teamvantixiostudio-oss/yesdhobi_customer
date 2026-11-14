import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LaundryItemIcon extends StatelessWidget {
  final String iconKey;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const LaundryItemIcon({
    super.key,
    required this.iconKey,
    this.size = 46.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    final effectiveBg = backgroundColor ?? const Color(0xFFEFF4FF);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: _buildIcon(effectiveColor),
      ),
    );
  }

  Widget _buildIcon(Color tint) {
    switch (iconKey.toLowerCase()) {
      case 'shirt':
        return Icon(Icons.dry_cleaning_outlined, color: tint, size: size * 0.52);
      case 'tshirt':
        return Icon(Icons.checkroom_rounded, color: tint, size: size * 0.52);
      case 'jeans':
      case 'pants':
        return Icon(Icons.style_outlined, color: tint, size: size * 0.52);
      case 'saree':
        return Icon(Icons.stars_rounded, color: tint, size: size * 0.52);
      case 'suit':
      case 'coat':
      case 'jacket':
        return Icon(Icons.dry_cleaning_rounded, color: tint, size: size * 0.52);
      case 'dress':
      case 'frock':
      case 'lehanga':
        return Icon(Icons.auto_awesome_rounded, color: tint, size: size * 0.52);
      case 'kids':
        return Icon(Icons.child_care_rounded, color: tint, size: size * 0.52);
      case 'sweater':
        return Icon(Icons.layers_rounded, color: tint, size: size * 0.52);
      case 'bedsheet':
        return Icon(Icons.bed_outlined, color: tint, size: size * 0.52);
      case 'towel':
      case 'scarf':
      case 'dupatta':
        return Icon(Icons.layers_outlined, color: tint, size: size * 0.52);
      case 'shoes':
      case 'socks':
        return Icon(Icons.snowshoeing_rounded, color: tint, size: size * 0.52);
      case 'steam':
        return Icon(Icons.sanitizer_outlined, color: tint, size: size * 0.52);
      case 'sofa':
        return Icon(Icons.weekend_rounded, color: tint, size: size * 0.52);
      case 'curtain':
        return Icon(Icons.curtains_rounded, color: tint, size: size * 0.52);
      case 'suitcase':
      case 'luggage':
        return Icon(Icons.luggage_rounded, color: tint, size: size * 0.52);
      case 'toy':
        return Icon(Icons.smart_toy_rounded, color: tint, size: size * 0.52);
      case 'carpet':
      case 'mat':
        return Icon(Icons.texture_rounded, color: tint, size: size * 0.52);
      case 'home':
        return Icon(Icons.home_outlined, color: tint, size: size * 0.52);
      default:
        return Icon(Icons.local_laundry_service_outlined, color: tint, size: size * 0.52);
    }
  }
}
