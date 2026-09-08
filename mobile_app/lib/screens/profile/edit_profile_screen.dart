import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _emailController = TextEditingController(text: widget.user.email);
    _addressController = TextEditingController(text: widget.user.address);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _save(AuthProvider authProvider) async {
    final success = await authProvider.updateProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      profilePicture: _pickedImage,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Update failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final photoUrl = widget.user.profilePicture != null
        ? ApiConfig.imageUrl(widget.user.profilePicture)
        : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null),
                    child: (_pickedImage == null && photoUrl.isEmpty)
                        ? Text(
                            widget.user.username.isNotEmpty
                                ? widget.user.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _pickImage,
              child: const Text('Change Photo'),
            ),
          ),
          const SizedBox(height: 24),

          const Text('First Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          const Text('Last Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          const Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          const Text('Address', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          const Text(
            'To change your phone number, go back to Profile and use "Change" next to your phone number — it requires OTP verification.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 11),
          ),

          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () => _save(authProvider),
                        child: const Text('Save'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}