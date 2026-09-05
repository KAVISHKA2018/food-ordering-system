import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/pin_input_pad.dart';

/// A self-contained "PIN Login" settings card — drop this widget anywhere
/// in the Profile screen's layout. Manages its own enable/disable flow.
class PinSettingsSection extends StatefulWidget {
  const PinSettingsSection({super.key});

  @override
  State<PinSettingsSection> createState() => _PinSettingsSectionState();
}

class _PinSettingsSectionState extends State<PinSettingsSection> {
  bool _busy = false;

  Future<void> _handleToggle(bool enable, AuthProvider auth) async {
    if (!enable) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Disable PIN Login'),
          content: const Text('You\'ll need to log in with your username/phone and password next time.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disable')),
          ],
        ),
      );
      if (confirmed != true) return;

      setState(() => _busy = true);
      final success = await auth.disablePin();
      setState(() => _busy = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'PIN login disabled' : (auth.errorMessage ?? 'Failed'))),
      );
      return;
    }

    // Enabling — collect and confirm a new 6-digit PIN.
    final pin = await _collectNewPin();
    if (pin == null) return;

    setState(() => _busy = true);
    final success = await auth.enablePin(pin);
    setState(() => _busy = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'PIN login enabled' : (auth.errorMessage ?? 'Failed'))),
    );
  }

  Future<String?> _collectNewPin() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _CreatePinSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final pinEnabled = auth.user?['pin_enabled'] == true;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: SwitchListTile(
        title: const Text('PIN Login'),
        subtitle: Text(
          pinEnabled
              ? 'Enabled — you can log in with your PIN'
              : 'Log in quickly with a 4-digit PIN instead of your password',
          style: const TextStyle(fontSize: 12),
        ),
        value: pinEnabled,
        activeColor: AppColors.primary,
        onChanged: _busy ? null : (value) => _handleToggle(value, auth),
        secondary: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.lock_outline),
      ),
    );
  }
}

class _CreatePinSheet extends StatefulWidget {
  const _CreatePinSheet();

  @override
  State<_CreatePinSheet> createState() => _CreatePinSheetState();
}

class _CreatePinSheetState extends State<_CreatePinSheet> {
  String? _firstPin;
  final _pinKey = GlobalKey<PinInputPadState>();
  String? _errorText;

  void _onEntered(String pin) {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _errorText = null;
      });
      _pinKey.currentState?.clear();
      return;
    }

    if (pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _errorText = 'PINs didn\'t match. Try again.';
      });
      _pinKey.currentState?.clear();
      return;
    }

    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4),
          )),
          const SizedBox(height: 20),
          Text(
            _firstPin == null ? 'Create a 4-digit PIN' : 'Confirm your PIN',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          PinInputPad(key: _pinKey, length: 4, onCompleted: _onEntered, errorText: _errorText),
        ],
      ),
    );
  }
}