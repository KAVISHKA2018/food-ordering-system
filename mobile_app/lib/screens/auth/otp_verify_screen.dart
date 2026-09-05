import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/pin_input_pad.dart';
import '../home/home_screen.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  final Map<String, String> registrationData;

  const OtpVerifyScreen({
    super.key,
    required this.phoneNumber,
    required this.registrationData,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _pinKey = GlobalKey<PinInputPadState>();
  String? _errorText;
  bool _working = false;

  Future<void> _onCompleted(String code) async {
    setState(() {
      _working = true;
      _errorText = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final otpResult = await auth.verifyOtp(widget.phoneNumber, code);

    if (!mounted) return;

    if (!otpResult['success']) {
      setState(() {
        _working = false;
        _errorText = otpResult['error'] ?? 'Incorrect code';
      });
      _pinKey.currentState?.clear();
      return;
    }

    // Phone verified — now complete the registration with all the details
    // collected on the previous screen.
    final registered = await auth.completeRegistration(widget.registrationData);

    if (!mounted) return;
    setState(() => _working = false);

    if (registered) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Registration failed. Please try again.')),
      );
      Navigator.pop(context); // back to Register screen to fix any issue (e.g. username taken)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.sms_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text('Verify Your Number', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Enter the 4-digit code sent to ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (_working)
                const CircularProgressIndicator()
              else
                PinInputPad(key: _pinKey, length: 4, onCompleted: _onCompleted, errorText: _errorText),
            ],
          ),
        ),
      ),
    );
  }
}