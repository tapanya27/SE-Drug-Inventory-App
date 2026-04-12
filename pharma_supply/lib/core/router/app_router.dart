import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/pharmacy/screens/pharmacy_dashboard_screen.dart';
import '../../features/pharmacy/screens/place_order_screen.dart';
import '../../features/pharmacy/screens/order_tracking_screen.dart';
import '../../features/pharmacy/screens/payment_simulation_screen.dart';
import '../../features/pharmacy/screens/pharmacy_inventory_screen.dart';
import '../../features/pharmacy/screens/document_upload_screen.dart';
import '../../features/warehouse/screens/warehouse_dashboard_screen.dart';
import '../../features/warehouse/screens/warehouse_inventory_screen.dart';
import '../../features/company/screens/company_dashboard_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../services/api_service.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = ApiService.token != null;
      final role = ApiService.userRole;
      final isVerified = ApiService.isVerified;
      
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSignup = state.matchedLocation == '/signup';

      // Helper to determine the correct home for the current role
      String getHomePath() {
        if (role == 'Warehouse') return '/warehouse_dashboard';
        if (role == 'Company') return '/company_dashboard';
        if (role == 'Admin') return '/admin_dashboard';
        if (role == 'PHARMACY' || role == 'Pharmacy Store') {
          return isVerified ? '/pharmacy_dashboard' : '/document_upload';
        }
        return '/login';
      }

      // 1. Unauthenticated users can only be on login/signup
      if (!isLoggedIn) {
        return (isGoingToLogin || isGoingToSignup) ? null : '/login';
      }

      // 2. Logged in users shouldn't be on login/signup
      if (isGoingToLogin || isGoingToSignup) {
        return getHomePath();
      }

      // 3. Role-Based Access Guards
      final currentPath = state.matchedLocation;
      
      // Pharmacy-only paths (including verification check)
      final isPharmacyPath = currentPath.startsWith('/pharmacy_') || 
                            currentPath == '/place_order' || 
                            currentPath == '/track_deliveries' || 
                            currentPath == '/document_upload' ||
                            currentPath == '/payment_simulation';
      
      final isWarehousePath = currentPath.startsWith('/warehouse_');
      final isCompanyPath = currentPath.startsWith('/company_');
      final isAdminPath = currentPath.startsWith('/admin_');

      bool isUserPharmacy = (role == 'PHARMACY' || role == 'Pharmacy Store');

      // GUARD: Non-pharmacy roles cannot access pharmacy paths
      if (isPharmacyPath && !isUserPharmacy) return getHomePath();
      
      // GUARD: Non-warehouse roles cannot access warehouse paths
      if (isWarehousePath && role != 'Warehouse') return getHomePath();
      
      // GUARD: Non-company roles cannot access company paths
      if (isCompanyPath && role != 'Company') return getHomePath();
      
      // GUARD: Non-admin roles cannot access admin paths
      if (isAdminPath && role != 'Admin') return getHomePath();

      // 4. Pharmacy Verification Enforcement (Only for Pharmacies)
      if (isUserPharmacy) {
        final isGoingToUpload = currentPath == '/document_upload';
        if (!isVerified && !isGoingToUpload) return '/document_upload';
        if (isVerified && isGoingToUpload) return '/pharmacy_dashboard';
      }

      return null;
    },

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
        path: '/company_dashboard',
        builder: (context, state) => const CompanyDashboardScreen(),
      ),
      GoRoute(
        path: '/admin_dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
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
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            // If extra is lost (e.g. page refresh on web), go back to order page
            return const PlaceOrderScreen();
          }
          final amount = (extra['amount'] as num?)?.toDouble() ?? 0.0;
          final rawItems = extra['items'] as List<dynamic>? ?? [];
          final items = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final warehouseId = extra['warehouse_id'] as int?;
          
          return PaymentSimulationScreen(
            amount: amount,
            items: items,
            warehouseId: warehouseId,
          );

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
      GoRoute(
        path: '/document_upload',
        builder: (context, state) => const DocumentUploadScreen(),
      ),
    ],
  );
}
