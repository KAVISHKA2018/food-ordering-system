import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'config/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/deliveries/deliveries_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryRestoreSession()),
      ],
      child: MaterialApp(
        title: 'Delivery Rider App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _StartupGate(),
      ),
    );
  }
}

/// Waits for the initial session check to finish, then routes to either
/// the deliveries dashboard (already logged in) or the login screen.
class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.checkingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isLoggedIn ? const DeliveriesListScreen() : const LoginScreen();
  }
}