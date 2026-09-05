import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/pin_input_pad.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

enum _LoginMode { pin, passwordOnly, full }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _checkingDevice = true;
  _LoginMode _mode = _LoginMode.full;

  String? _rememberedPhone;
  String? _rememberedName;

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String? _passwordOnlyError;

  final _pinKey = GlobalKey<PinInputPadState>();
  String? _pinError;
  bool _pinSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkDeviceState();
  }

  Future<void> _checkDeviceState() async {
    final remembered = await AuthService.getRememberedUser();
    final storedToken = await ApiService.getAccessToken();
    final stillLoggedIn = storedToken != null && storedToken.isNotEmpty;

    if (!mounted) return;

    setState(() {
      _checkingDevice = false;

      if (remembered != null && remembered['pinEnabled'] == true) {
        // PIN, once enabled, is a persistent convenience shortcut —
        // offered regardless of whether the session was logged out.
        _mode = _LoginMode.pin;
        _rememberedPhone = remembered['phone'];
        _rememberedName = remembered['name'];
      } else if (remembered != null && stillLoggedIn) {
        // Session was never explicitly logged out — only ask for the
        // password, no need to re-type the username/phone.
        _mode = _LoginMode.passwordOnly;
        _rememberedPhone = remembered['phone'];
        _rememberedName = remembered['name'];
      } else {
        // Fresh device, or the customer explicitly logged out — full form.
        _mode = _LoginMode.full;
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleFullLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithPassword(
      _identifierController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      _goHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Login failed')),
      );
    }
  }

  Future<void> _handlePasswordOnlyLogin() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordOnlyError = 'Please enter your password');
      return;
    }

    setState(() => _passwordOnlyError = null);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithPassword(_rememberedPhone!, _passwordController.text);

    if (!mounted) return;
    if (success) {
      _goHome();
    } else {
      setState(() => _passwordOnlyError = auth.errorMessage ?? 'Incorrect password');
    }
  }

  Future<void> _handlePinLogin(String pin) async {
    setState(() {
      _pinSubmitting = true;
      _pinError = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithPin(_rememberedPhone!, pin);

    if (!mounted) return;
    setState(() => _pinSubmitting = false);

    if (success) {
      _goHome();
    } else {
      setState(() => _pinError = auth.errorMessage ?? 'Incorrect PIN');
      _pinKey.currentState?.clear();
    }
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _usePasswordInstead() {
    setState(() {
      _mode = _LoginMode.passwordOnly;
      _passwordController.clear();
      _passwordOnlyError = null;
      // _rememberedPhone / _rememberedName are already set from PIN mode —
      // keep them so the password-only screen still shows "Welcome back".
    });
  }

  Future<void> _switchAccount() async {
    await AuthService.logout(); // clears stored tokens
    await AuthService.clearRememberedUser();
    if (!mounted) return;
    setState(() {
      _mode = _LoginMode.full;
      _rememberedPhone = null;
      _rememberedName = null;
      _identifierController.clear();
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingDevice) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.fastfood, size: 72, color: AppColors.primary),
              const SizedBox(height: 20),
              if (_mode == _LoginMode.pin)
                ..._buildPinModeContent(auth)
              else if (_mode == _LoginMode.passwordOnly)
                ..._buildPasswordOnlyContent(auth)
              else
                ..._buildFullFormContent(auth),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFullFormContent(AuthProvider auth) {
    return [
      const Text(
        'Welcome Back',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text(
        'Log in to continue ordering',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGrey, fontSize: 14),
      ),
      const SizedBox(height: 32),
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _identifierController,
              decoration: const InputDecoration(
                labelText: 'Username or Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            auth.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleFullLogin,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Register', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildPasswordOnlyContent(AuthProvider auth) {
    return [
      Text(
        'Welcome back, $_rememberedName!',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Text(
        _rememberedPhone ?? '',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter your password to continue',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGrey, fontSize: 13),
      ),
      const SizedBox(height: 28),
      TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Password',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.lock_outline),
          errorText: _passwordOnlyError,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        onSubmitted: (_) => _handlePasswordOnlyLogin(),
      ),
      const SizedBox(height: 20),
      auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton(
              onPressed: _handlePasswordOnlyLogin,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Login', style: TextStyle(fontSize: 16)),
            ),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: _switchAccount,
          child: const Text('Not you? Switch Account'),
        ),
      ),
    ];
  }

  List<Widget> _buildPinModeContent(AuthProvider auth) {
    return [
      Text(
        'Welcome back, $_rememberedName!',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Text(
        _rememberedPhone ?? '',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter your PIN to continue',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGrey, fontSize: 13),
      ),
      const SizedBox(height: 28),
      _pinSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: PinInputPad(
                key: _pinKey,
                length: 4,
                onCompleted: _handlePinLogin,
                errorText: _pinError,
              ),
            ),
      const SizedBox(height: 24),
      Center(
        child: TextButton(
          onPressed: _usePasswordInstead,
          child: const Text('Use Password Instead'),
        ),
      ),
      Center(
        child: TextButton(
          onPressed: _switchAccount,
          child: const Text('Not you? Switch Account'),
        ),
      ),
    ];
  }
}