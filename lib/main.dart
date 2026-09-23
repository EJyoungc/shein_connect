import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as rpd;
import 'package:provider/provider.dart' as pvd;
import 'core/constants/app_config.dart';
import 'core/errors/app_logger.dart';
import 'core/services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/session_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize environment configuration
  await AppConfig.initialize();
  AppLogger.info('AppConfig initialized. Env: ${AppConfig.environment}', 'Main');

  // 2. Initialize Supabase Client
  await SupabaseService.initialize();

  runApp(
    // ProviderScope allows Riverpod to operate globally across the entire app
    const rpd.ProviderScope(
      child: SheinProcApp(),
    ),
  );
}

class SheinProcApp extends StatelessWidget {
  const SheinProcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return pvd.MultiProvider(
      providers: [
        pvd.ChangeNotifierProvider(create: (_) => AuthService()),
        pvd.ChangeNotifierProvider(create: (_) => CartService()),
        pvd.ChangeNotifierProvider(create: (_) => SessionService()),
      ],
      child: MaterialApp(
        title: 'SheIn Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
