import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import 'pin_settings_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing(UserModel user) {
    _emailController.text = user.email;
    _phoneController.text = user.phoneNumber;
    setState(() => _editing = true);
  }

  Future<void> _saveChanges(AuthProvider authProvider) async {
    final success = await authProvider.updateProfile(
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Update failed')),
      );
    }
  }

  Future<void> _confirmLogout(AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userJson = authProvider.user;

    if (userJson == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = UserModel.fromJson(userJson);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _startEditing(user),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user.username,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.roleLabel,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const PinSettingsSection(),
          const SizedBox(height: 20),
          const Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          _editing
              ? TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                )
              : Text(user.email.isEmpty ? 'Not set' : user.email, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          _editing
              ? TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                )
              : Text(user.phoneNumber.isEmpty ? 'Not set' : user.phoneNumber, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 32),
          if (_editing)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _editing = false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: authProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () => _saveChanges(authProvider),
                          child: const Text('Save'),
                        ),
                ),
              ],
            ),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            onPressed: () => _confirmLogout(authProvider),
          ),
        ],
      ),
    );
  }
}