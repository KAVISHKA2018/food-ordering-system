import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'config/app_theme.dart';
import 'services/notification_service.dart';
import 'screens/orders/order_history_screen.dart';
import 'screens/reservations/reservation_history_screen.dart';

import 'screens/auth/login_screen.dart';

import 'screens/activity/activity_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  final cartProvider = CartProvider();
  await cartProvider.init(); // loads any previously saved cart from disk

  runApp(MyApp(cartProvider: cartProvider));
}

class MyApp extends StatelessWidget {
  final CartProvider cartProvider;
  const MyApp({super.key, required this.cartProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: cartProvider),
      ],
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'Food Ordering App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const LoginScreen(),
        routes: {
          '/orders': (_) => const ActivityHubScreen(initialTabIndex: 0),
          '/reservations': (_) => const ActivityHubScreen(initialTabIndex: 0),
        },
      ),
    );
  }
}