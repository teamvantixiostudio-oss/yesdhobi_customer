import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:yes_dhobi/main.dart';
import 'package:yes_dhobi/screens/splash_screen.dart';
import 'package:yes_dhobi/screens/onboarding_screen.dart';
import 'package:yes_dhobi/screens/register_screen.dart';
import 'package:yes_dhobi/screens/login_screen.dart';
import 'package:yes_dhobi/screens/otp_verification_screen.dart';
import 'package:yes_dhobi/screens/home_screen.dart';
import 'package:yes_dhobi/screens/select_items_screen.dart';
import 'package:yes_dhobi/screens/schedule_pickup_screen.dart';
import 'package:yes_dhobi/screens/order_summary_screen.dart';
import 'package:yes_dhobi/screens/order_success_screen.dart';
import 'package:yes_dhobi/screens/track_order_screen.dart';
import 'package:yes_dhobi/screens/manage_addresses_screen.dart';
import 'package:yes_dhobi/screens/help_support_screen.dart';
import 'package:yes_dhobi/screens/order_details_screen.dart';
import 'package:yes_dhobi/theme/app_theme.dart';
import 'package:yes_dhobi/models/laundry_item.dart';

void main() {
  testWidgets('Yes Dhobi app starts with splash screen and transitions',
      (WidgetTester tester) async {
    await tester.pumpWidget(const YesDhobiApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Yes Dhobi'), findsOneWidget);
    expect(find.text('YOUR LAUNDRY, DELIVERED'), findsOneWidget);

    // Advance timer past splash screen
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Book in 60 Seconds'), findsOneWidget);
  });

  testWidgets('Register screen renders all exact fields and social logins',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RegisterScreen(),
      ),
    );
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Join Yes Dhobi to experience hassle-free laundry'),
        findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
  });

  testWidgets('Login screen renders mobile login and Google button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Enter your mobile number to sign in securely'),
        findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('OTP screen renders 4 boxes and timer',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OtpVerificationScreen(phoneNumber: '+91 98765 43210'),
      ),
    );
    expect(find.text('Verify Code'), findsOneWidget);
    expect(find.text('Verify & Continue'), findsOneWidget);
    expect(find.text('Resend OTP via SMS'), findsOneWidget);
  });

  testWidgets('Home screen renders 4 tabs properly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
    expect(find.text('Good Morning, Rahul!'), findsOneWidget);
    expect(find.text('Choose Service'), findsOneWidget);
    expect(find.text('Wash & Fold'), findsOneWidget);
  });

  testWidgets('Select Items screen renders category tabs and View Basket',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SelectItemsScreen(
            initialCategory: ServiceCategory.washAndFold),
      ),
    );
    expect(find.text('Select Items'), findsOneWidget);
    expect(find.text('Shirt'), findsWidgets);
    expect(find.text('View Basket'), findsOneWidget);
  });

  testWidgets(
      'Instant Pickup screen renders instant mode and Confirm button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SchedulePickupScreen(),
      ),
    );
    expect(find.text('Instant Pickup'), findsWidgets);
    expect(find.text('Pickup Timing'), findsOneWidget);
    expect(find.text('Pickup Location'), findsOneWidget);
  });

  testWidgets(
      'Order Summary screen renders Bill Details and Place Order button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OrderSummaryScreen(),
      ),
    );
    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('Bill Details'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Delivery Partner Fee'), findsOneWidget);
    expect(find.textContaining('Place Order'), findsOneWidget);
  });

  testWidgets('Order Placed Successfully screen renders confirmation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OrderSuccessScreen(),
      ),
    );
    expect(find.text('Order Placed Successfully!'), findsOneWidget);
    expect(find.text('#YD-892740'), findsOneWidget);
    expect(find.text('Track Order'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets('Track Order screen renders timeline stepper and rider card',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const TrackOrderScreen(),
      ),
    );
    expect(find.text('Track Order'), findsOneWidget);
    expect(find.text('ESTIMATED DELIVERY'), findsOneWidget);
    expect(find.text('Order Placed'), findsOneWidget);
    expect(find.text('Rider On Way'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
  });

  testWidgets('Manage Addresses screen renders addresses and add button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ManageAddressesScreen(),
      ),
    );
    expect(find.text('Manage Addresses'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('+ Add New Address'), findsOneWidget);
  });

  testWidgets('Help & Support screen renders FAQs, WhatsApp, and Live Chat',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HelpSupportScreen(),
      ),
    );
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    expect(find.text('How do I schedule a pickup?'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Call Support'), findsOneWidget);
    expect(find.text('Start Live Chat'), findsOneWidget);
  });

  testWidgets('Order Details screen renders exact layout, items, bill and invoice button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OrderDetailsScreen(),
      ),
    );
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('ID: #YD-881590'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
    expect(find.text('Completed on 18 Oct 2026, 4:15 PM'), findsOneWidget);
    expect(find.text('Items Breakdown'), findsOneWidget);
    expect(find.text('Bill Details'), findsOneWidget);
    expect(find.text('Delivery Address'), findsOneWidget);
    expect(find.text('YOUR RATING'), findsOneWidget);
    expect(find.text('Delivered by Rahul'), findsOneWidget);
    expect(find.text('5.0'), findsOneWidget);
    expect(find.text('Download Invoice'), findsOneWidget);
  });
}
