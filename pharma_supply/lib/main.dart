import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/api_service.dart';
import 'core/services/stripe_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const String publishableKey = 'pk_test_51Rvbfd5MJAfJunXFqZnWIWqnFbwR3s2cbBAfEaRc9LfwdykXrD9wxEwPH18hr5hhkhN1mPXmJxNbpeS5hq9VISYZ00CTvV8vch';

  PaymentService.instance.initialize(publishableKey);

  await ApiService.init();
  runApp(const PharmaSupplyApp());
}

class PharmaSupplyApp extends StatelessWidget {
  const PharmaSupplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pharma Supply System',
      theme: AppTheme.theme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
