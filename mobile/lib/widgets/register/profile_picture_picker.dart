import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/auth_service.dart';

typedef ProfilePictureChanged = void Function(ProfilePicture profilePicture);
typedef CustomProfilePictureChanged = void Function(String? path);

class ProfilePicturePicker extends StatefulWidget {
  const ProfilePicturePicker({
    required this.selected,
    required this.onProfilePictureChanged,
    required this.onCustomPreviewChanged,
    super.key,
    this.customPreview,
    this.showOnlyFree = false,
  });

  final ProfilePicture selected;
  final String? customPreview;
  final ProfilePictureChanged onProfilePictureChanged;
  final CustomProfilePictureChanged onCustomPreviewChanged;
  final bool showOnlyFree;

  @override
  State<ProfilePicturePicker> createState() => _ProfilePicturePickerState();
}

class _ProfilePicturePickerState extends State<ProfilePicturePicker> {
  final AuthService _authService = AuthService();
  Set<int> _ownedProfilePictures = {};
  late VoidCallback _userListener;

  @override
  void initState() {
    super.initState();
    if (!widget.showOnlyFree) {
      _loadOwnedProfilePictures();
      _userListener = () {
        if (mounted) {
          _loadOwnedProfilePictures();
        }
      };
      _authService.notifier.addListener(_userListener);
    }
  }

  @override
  void dispose() {
    if (!widget.showOnlyFree) {
      _authService.notifier.removeListener(_userListener);
    }
    super.dispose();
  }

  Future<void> _loadOwnedProfilePictures() async {
    final user = _authService.notifier.value;
    if (user == null) return;

    final unlocked = <int>{1, 2, 3};

    for (final item in user.shopItems) {
      if (item.itemId.startsWith('profile_')) {
        final profileNum = int.tryParse(
          item.itemId.replaceFirst('profile_', ''),
        );
        if (profileNum != null) {
          unlocked.add(profileNum);
        }
      }
    }

    setState(() {
      _ownedProfilePictures = unlocked;
    });
  }

  bool _isOwned(ProfilePicture pp) {
    if (widget.showOnlyFree) return true;
    return _ownedProfilePictures.contains(pp.value);
  }

  void _selectProfile(ProfilePicture pp) {
    if (!_isOwned(pp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette photo de profil doit être achetée en boutique'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    widget.onCustomPreviewChanged(null);
    widget.onProfilePictureChanged(pp);
  }

  Future<void> _pickCustomProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
    widget.onCustomPreviewChanged(base64String);
  }

  @override
  Widget build(BuildContext context) {
    final profilePictures =
        widget.showOnlyFree
            ? [
              ProfilePicture.profile1,
              ProfilePicture.profile2,
              ProfilePicture.profile3,
            ]
            : ProfilePicture.values;

    final hasCustom =
        widget.customPreview != null && widget.customPreview!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Predefined profile pictures
            for (final pp in profilePictures)
              Builder(
                builder: (context) {
                  final isOwned = _isOwned(pp);
                  final isSelected = widget.selected == pp && !hasCustom;

                  return GestureDetector(
                    onTap: () => _selectProfile(pp),
                    child: Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.blueAccent
                                      : (isOwned || widget.showOnlyFree
                                          ? Colors.transparent
                                          : Colors.grey),
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: Colors.blue.withValues(
                                          alpha: 0.16,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                    : null,
                            image: DecorationImage(
                              image: AssetImage(
                                'lib/assets/profile/${pp.value}.png',
                              ),
                              fit: BoxFit.cover,
                              opacity:
                                  isOwned || widget.showOnlyFree ? 1.0 : 0.3,
                            ),
                          ),
                        ),
                        if (!isOwned && !widget.showOnlyFree)
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Colors.white70,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            // Camera button - always visible (like web client's "+" button)
            GestureDetector(
              onTap: _pickCustomProfilePicture,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade600, width: 2),
                  color: Colors.white,
                ),
                child: Center(
                  child: Icon(Icons.camera_alt, color: Colors.grey.shade500),
                ),
              ),
            ),
            // Custom image preview - shown separately when exists (like web client)
            if (hasCustom)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueAccent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildCustomImage(widget.customPreview!),
                ),
              ),
          ],
        ),

        if (hasCustom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: () => widget.onCustomPreviewChanged(null),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Retirer l'image personnalisée",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomImage(String path) {
    if (path.startsWith('data:')) {
      try {
        final parts = path.split(',');
        final payload = parts.length > 1 ? parts.last : parts.first;
        final bytes = base64Decode(payload);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  Icon(Icons.broken_image, color: Colors.grey.shade500),
        );
      } on Object catch (_) {
        return Icon(Icons.broken_image, color: Colors.grey.shade500);
      }
    }

    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
                Icon(Icons.broken_image, color: Colors.grey.shade500),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey.shade500),
    );
  }
}
