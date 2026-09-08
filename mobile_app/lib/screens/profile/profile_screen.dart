import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/pin_input_pad.dart';
import '../auth/login_screen.dart';
import 'pin_settings_section.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  // --- Change phone number: two-step flow (enter number -> verify OTP) ---

  Future<void> _openChangePhoneFlow(AuthProvider authProvider, String currentPhone) async {
    final newPhoneController = TextEditingController();
    final pinKey = GlobalKey<PinInputPadState>();
    int step = 0; // 0 = enter new number, 1 = enter OTP
    String? stepError;
    bool submitting = false;
    String enteredPhone = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> requestCode() async {
              final phone = newPhoneController.text.trim();
              if (phone.isEmpty) {
                setDialogState(() => stepError = 'Please enter a phone number.');
                return;
              }
              setDialogState(() {
                submitting = true;
                stepError = null;
              });
              final result = await authProvider.requestOtp(phone);
              setDialogState(() => submitting = false);

              if (result['success']) {
                enteredPhone = phone;
                setDialogState(() => step = 1);
                if (result['debugOtp'] != null && mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Mock OTP (dev only): ${result['debugOtp']}')),
                  );
                }
              } else {
                setDialogState(() => stepError = result['error']?.toString() ?? 'Failed to send OTP.');
              }
            }

            Future<void> verifyAndChange(String code) async {
              setDialogState(() {
                submitting = true;
                stepError = null;
              });

              final verifyResult = await authProvider.verifyOtp(enteredPhone, code);
              if (!verifyResult['success']) {
                setDialogState(() {
                  submitting = false;
                  stepError = verifyResult['error']?.toString() ?? 'Invalid code.';
                });
                pinKey.currentState?.clear();
                return;
              }

              final changeSuccess = await authProvider.changePhoneNumber(enteredPhone);
              setDialogState(() => submitting = false);

              if (changeSuccess) {
                if (context.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Phone number updated successfully')),
                  );
                }
              } else {
                setDialogState(() => stepError = authProvider.errorMessage ?? 'Could not update phone number.');
                pinKey.currentState?.clear();
              }
            }

            return AlertDialog(
              title: Text(step == 0 ? 'Change Phone Number' : 'Verify New Number'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step == 0) ...[
                    Text('Current: $currentPhone',
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPhoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'New Phone Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Enter the 4-digit code sent to $enteredPhone',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: PinInputPad(
                        key: pinKey,
                        length: 4,
                        onCompleted: verifyAndChange,
                        errorText: null,
                      ),
                    ),
                  ],
                  if (stepError != null) ...[
                    const SizedBox(height: 10),
                    Text(stepError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
                ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                if (step == 0)
                  ElevatedButton(
                    onPressed: submitting ? null : requestCode,
                    child: submitting
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send Code'),
                  ),
              ],
            );
          },
        );
      },
    );
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
    final photoUrl = user.profilePicture != null ? ApiConfig.imageUrl(user.profilePicture) : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user.fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              '@${user.username}',
              style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
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
          Text(user.email.isEmpty ? 'Not set' : user.email, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),

          const Text('Address', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          Text(user.address.isEmpty ? 'Not set' : user.address, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),

          const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  user.phoneNumber.isEmpty ? 'Not set' : user.phoneNumber,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => _openChangePhoneFlow(authProvider, user.phoneNumber),
                child: const Text('Change'),
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