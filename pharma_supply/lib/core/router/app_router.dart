import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/pharmacy/screens/pharmacy_dashboard_screen.dart';
import '../../features/pharmacy/screens/place_order_screen.dart';
import '../../features/pharmacy/screens/order_tracking_screen.dart';
import '../../features/pharmacy/screens/payment_simulation_screen.dart';
import '../../features/pharmacy/screens/pharmacy_inventory_screen.dart';
import '../../features/warehouse/screens/warehouse_dashboard_screen.dart';
import '../../features/warehouse/screens/warehouse_inventory_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/pharmacy_dashboard',
        builder: (context, state) => const PharmacyDashboardScreen(),
      ),
      GoRoute(
        path: '/place_order',
        builder: (context, state) => const PlaceOrderScreen(),
      ),
      GoRoute(
        path: '/track_deliveries',
        builder: (context, state) => const OrderTrackingScreen(),
      ),
      GoRoute(
        path: '/payment_simulation',
        builder: (context, state) {
          final amount = state.extra as double? ?? 0.0;
          return PaymentSimulationScreen(amount: amount);
        },
      ),
      GoRoute(
        path: '/warehouse_dashboard',
        builder: (context, state) => const WarehouseDashboardScreen(),
      ),
      GoRoute(
        path: '/pharmacy_inventory',
        builder: (context, state) => const PharmacyInventoryScreen(),
      ),
      GoRoute(
        path: '/warehouse_inventory',
        builder: (context, state) => const WarehouseInventoryScreen(),
      ),
    ],
  );
}
