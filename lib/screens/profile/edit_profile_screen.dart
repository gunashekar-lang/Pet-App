import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/web_camera.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';

/// Edit the signed-in user's public seller profile.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _bioController;
  late String _avatarUrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController = TextEditingController(text: user.fullName);
    _phoneController = TextEditingController(text: user.phone);
    _cityController = TextEditingController(text: user.city);
    _bioController = TextEditingController(text: user.bio);
    _avatarUrl = user.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: CustomButton(
          label: 'Save changes',
          icon: Icons.check_rounded,
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;

            final saved = await auth.updateProfile(
              fullName: _nameController.text.trim(),
              phone: Validators.normalizeIndianPhone(_phoneController.text),
              city: _cityController.text.trim(),
              bio: _bioController.text.trim(),
              avatarUrl: _avatarUrl,
            );
            if (!context.mounted) return;
            Nav.pop(context);

            final messenger = ScaffoldMessenger.of(context);
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    saved
                        ? 'Profile updated'
                        : 'Saved on this device only - the server rejected it',
                  ),
                  duration: const Duration(seconds: 8),
                ),
              );
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Center(
              child: Column(
                children: [
                  AppAvatar(url: _avatarUrl, initials: 'ME', size: 88),
                  Gap.h12,
                  OutlinedButton.icon(
                    onPressed: _pickAvatar,
                    icon: const Icon(Icons.photo_camera_outlined, size: 17),
                    label: const Text('Change photo'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: scheme.outline),
                      foregroundColor: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Gap.h24,
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: Validators.fullName,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            Gap.h16,
            TextFormField(
              initialValue: context.read<AuthService>().currentUser.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                helperText: 'Email cannot be changed',
              ),
            ),
            Gap.h16,
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              maxLength: 14,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixText: '+91  ',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
            ),
            Gap.h16,
            TextFormField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
            Gap.h16,
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'About you',
                alignLabelWithHint: true,
                hintText: 'Tell buyers a little about yourself and your pets',
              ),
            ),
            Gap.h24,
            const Text(
              'Account',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Gap.h10,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined, size: 20),
                    title: const Text('Identity verification'),
                    subtitle: Text(
                      auth.currentUser.isVerified
                          ? 'Verified — you have the trusted seller badge'
                          : 'Not verified yet',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      auth.currentUser.isVerified
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      color: auth.currentUser.isVerified
                          ? AppColors.success
                          : scheme.onSurface.withValues(alpha: 0.35),
                    ),
                    onTap: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Verification needs a government ID — coming soon',
                          ),
                        ),
                      ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded, size: 20),
                    title: const Text('Password & security'),
                    subtitle: const Text(
                      'Update your password and 2FA',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.35),
                    ),
                    onTap: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Security settings coming soon'),
                        ),
                      ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the system picker so the user chooses their own photo. The
  /// returned local path is stored on the profile and rendered by
  /// [AppAvatar] / [AppImage].
  Future<void> _pickAvatar() async {
    final choice = await showModalBottomSheet<_AvatarChoice>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_AvatarChoice(ImageSource.gallery)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_AvatarChoice(ImageSource.camera)),
            ),
            if (_avatarUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(const _AvatarChoice(null)),
              ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice.source == null) {
      setState(() => _avatarUrl = '');
      return;
    }

    try {
      String? path;
      if (choice.source == ImageSource.camera) {
        // On web the browser camera (getUserMedia) opens an in-app capture
        // sheet; fall back to image_picker when no camera is available.
        final bytes = await captureWebCameraImage(context: context);
        path = bytes != null ? bytesToJpegDataUri(bytes) : null;
        if (path == null) {
          final picked = await ImagePicker().pickImage(
            source: choice.source!,
            maxWidth: 1024,
            imageQuality: 85,
          );
          path = picked?.path;
        }
      } else {
        final picked = await ImagePicker().pickImage(
          source: choice.source!,
          maxWidth: 1024,
          imageQuality: 85,
        );
        path = picked?.path;
      }
      if (path == null || !mounted) return;
      setState(() => _avatarUrl = path!);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not open the camera or gallery on this '
                'device.'),
          ),
        );
    }
  }
}

/// Wrapper so "remove photo" can return a result from the sheet even though
/// there is no [ImageSource] for it.
class _AvatarChoice {
  const _AvatarChoice(this.source);
  final ImageSource? source;
}
