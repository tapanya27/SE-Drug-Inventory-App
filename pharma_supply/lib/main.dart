import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const PharmaSupplyApp());
}

class PharmaSupplyApp extends StatelessWidget {
  const PharmaSupplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add providers here later for State Management
        Provider<String>.value(value: 'DummyData'), 
      ],
      child: MaterialApp.router(
        title: 'Pharma Supply System',
        theme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
