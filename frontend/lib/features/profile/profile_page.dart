import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/avatar_crop_dialog.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/member_role.dart';
import '../../data/models/auth_user.dart';
import '../../providers/auth_provider.dart';
import '../settings/widgets/change_password_dialog.dart';

/// A full profile editor: avatar, identity, contact and work details, persisted
/// to the backend so they are available across the app (AGENTS.md §1).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _jobTitle;
  late final TextEditingController _department;
  late final TextEditingController _location;
  late final TextEditingController _bio;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final AuthUser? u = ref.read(authControllerProvider).asData?.value.user;
    _name = TextEditingController(text: u?.name ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _jobTitle = TextEditingController(text: u?.jobTitle ?? '');
    _department = TextEditingController(text: u?.department ?? '');
    _location = TextEditingController(text: u?.location ?? '');
    _bio = TextEditingController(text: u?.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _jobTitle.dispose();
    _department.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            jobTitle: _jobTitle.text.trim(),
            department: _department.text.trim(),
            location: _location.text.trim(),
            bio: _bio.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _changePhoto() async {
    final FilePickerResult? result =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.first.bytes;
    if (result == null || bytes == null || !mounted) {
      return;
    }
    final cropped = await cropAvatar(context, bytes);
    if (cropped == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateAvatar(cropped, 'avatar.png');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const ChangePasswordDialog(),
    );
    if ((ok ?? false) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthUser? user = ref.watch(authControllerProvider).asData?.value.user;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                _HeaderCard(user: user, onChangePhoto: _changePhoto),
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'Personal information',
                  child: Column(
                    children: <Widget>[
                      _ProfileField(
                        controller: _name,
                        label: 'Full name',
                        icon: Icons.person_outline,
                        validator: (String? v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                      ),
                      _ProfileField(
                        controller: _phone,
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _ProfileField(
                        controller: _location,
                        label: 'Location',
                        icon: Icons.place_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'Work',
                  child: Column(
                    children: <Widget>[
                      _ProfileField(
                        controller: _jobTitle,
                        label: 'Job title',
                        icon: Icons.badge_outlined,
                      ),
                      _ProfileField(
                        controller: _department,
                        label: 'Department',
                        icon: Icons.apartment_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'About',
                  child: _ProfileField(
                    controller: _bio,
                    label: 'Bio',
                    icon: Icons.notes_outlined,
                    maxLines: 4,
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save changes'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'Security',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_outline,
                        color: scheme.onSurfaceVariant),
                    title: const Text('Change password'),
                    subtitle: const Text('Update your account password'),
                    trailing: Icon(Icons.chevron_right,
                        color: scheme.onSurfaceVariant),
                    onTap: _changePassword,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The identity header: avatar (tap to change), name, email and role chip.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user, required this.onChangePhoto});

  final AuthUser? user;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String name = user?.name ?? 'User';
    final MemberRole role = user?.role ?? MemberRole.member;
    return DashboardCard(
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: onChangePhoto,
            borderRadius: BorderRadius.circular(36),
            child: Stack(
              children: <Widget>[
                UserAvatar(name: name, radius: 36, imageUrl: user?.avatarUrl),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: scheme.primary,
                    child: const Icon(Icons.camera_alt,
                        size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: role.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(role.label,
                      style: TextStyle(
                          color: role.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single labelled text field used throughout the profile form.
class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          alignLabelWithHint: maxLines > 1,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
