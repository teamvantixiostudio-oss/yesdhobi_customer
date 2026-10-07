import 'dart:async';
import 'package:flutter/material.dart';
import '../state/cart_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/yes_dhobi_logo.dart';
import '../services/api_client.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _logoSlideAnimation;

  late AnimationController _waveController;
  late Animation<double> _rippleAnimation;

  late AnimationController _progressController;

  Timer? _timer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Warm the live price list while the splash animation plays, so the item
    // screen opens on server prices rather than the built-in fallback.
    CartManager.instance.loadCatalogFromServer();

    // 1. Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _logoSlideAnimation = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Continuous water ripple pulse
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOutQuad),
    );

    // 3. Bottom sleek progress indicator
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();

    _entranceController.forward();

    // Auto-transition after 2.6 seconds
    _timer = Timer(const Duration(milliseconds: 2600), () {
      _navigateToNext();
    });
  }

  void _navigateToNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _timer?.cancel();

    final Widget targetScreen = ApiClient.instance.isAuthenticated
        ? const HomeScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entranceController.dispose();
    _waveController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _navigateToNext,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B1E),
        body: Stack(
          children: [
            // 1. Multi-Stop Atmospheric Luxury Gradient Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF06091A), // Deep Midnight Navy
                      Color(0xFF0A1236), // Rich Indigo
                      Color(0xFF0F1E5E), // Brand Royal Depth
                      Color(0xFF080D26), // Bottom Midnight
                    ],
                    stops: [0.0, 0.35, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Ambient Aqua Glow Mesh
            Positioned(
              top: screenSize.height * 0.22,
              left: screenSize.width * 0.5 - 160,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D2B4).withValues(alpha: 0.16),
                      const Color(0xFF2563EB).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Dynamic Water Ripple Waves Behind Logo
            Center(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  final progress = _rippleAnimation.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Ripple Ring
                      Container(
                        width: 140 + (progress * 130),
                        height: 140 + (progress * 130),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00D2B4).withValues(
                              alpha: (1.0 - progress) * 0.28,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Inner Echo Ring
                      Container(
                        width: 130 + (progress * 70),
                        height: 130 + (progress * 70),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: (1.0 - progress) * 0.18,
                            ),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 4. Subtle Ambient Floating Water Bubbles (Decorative)
            Positioned(
              top: screenSize.height * 0.12,
              left: screenSize.width * 0.15,
              child: _buildFloatingBubble(18, 0.15),
            ),
            Positioned(
              top: screenSize.height * 0.28,
              right: screenSize.width * 0.12,
              child: _buildFloatingBubble(24, 0.2),
            ),
            Positioned(
              bottom: screenSize.height * 0.28,
              left: screenSize.width * 0.12,
              child: _buildFloatingBubble(28, 0.12),
            ),
            Positioned(
              bottom: screenSize.height * 0.18,
              right: screenSize.width * 0.18,
              child: _buildFloatingBubble(16, 0.18),
            ),

            // 5. Central Hero Stage (Emblem + Exact Logo + Tagline)
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Elevated Frosted Glass Emblem Badge
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D2B4).withValues(alpha: 0.45),
                              blurRadius: 40,
                              spreadRadius: 4,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Center(
                          child: YesDhobiEmblemMark(
                            size: 64,
                            waveColor: const Color(0xFF00D2B4),
                            dropColor: const Color(0xFF0A0944),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Exact Brand Vector Logotype ("yes dhobi")
                      AnimatedBuilder(
                        animation: _entranceController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _logoSlideAnimation.value),
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const YesDhobiLogo(
                            height: 48,
                            variant: LogoVariant.white,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Brand Tagline with Golden Accent
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFFE2C07D).withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'YOUR LAUNDRY, DELIVERED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE2C07D),
                                letterSpacing: 2.2,
                              ),
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFE2C07D).withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Feature Highlights Pill Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPillTag('✨ Pure Fresh'),
                            _buildPillDivider(),
                            _buildPillTag('⚡ 24h Express'),
                            _buildPillDivider(),
                            _buildPillTag('👔 Eco Press'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 6. Footer (Sleek Aqua Progress Bar & Tagline)
            Positioned(
              bottom: 42,
              left: 32,
              right: 32,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sleek glowing progress loader
                    Container(
                      width: 120,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _progressController.value.clamp(0.05, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF00D2B4),
                                    Color(0xFF38BDF8),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Quick • Premium • Doorstep Delivery',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 0.6,
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

  Widget _buildPillTag(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildPillDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: const Color(0xFF00D2B4),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildFloatingBubble(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF00D2B4).withValues(alpha: opacity),
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity * 1.5),
          width: 0.8,
        ),
      ),
    );
  }
}
