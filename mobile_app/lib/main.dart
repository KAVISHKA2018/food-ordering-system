import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'config/app_theme.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/orders/order_history_screen.dart';
import 'screens/reservations/reservation_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'Food Ordering App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const LoginScreen(),
        routes: {
          '/orders': (_) => const OrderHistoryScreen(),
          '/reservations': (_) => const ReservationHistoryScreen(),
        },
      ),
    );
  }
}