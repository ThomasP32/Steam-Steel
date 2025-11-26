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
    widget.onCustomPreviewChanged(picked.path);
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

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
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
                                    color: Colors.blue.withValues(alpha: 0.16),
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
                          opacity: isOwned || widget.showOnlyFree ? 1.0 : 0.3,
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
        GestureDetector(
          onTap: _pickCustomProfilePicture,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasCustom ? Colors.blueAccent : Colors.grey.shade600,
                width: hasCustom ? 3 : 2,
              ),
              color: Colors.white,
              boxShadow:
                  hasCustom
                      ? [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                      : null,
            ),
            child:
                !hasCustom
                    ? Center(
                      child: Icon(Icons.add, color: Colors.grey.shade500),
                    )
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildCustomImage(widget.customPreview!),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomImage(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder:
          (_, _, _) => Icon(Icons.broken_image, color: Colors.grey.shade500),
    );
  }
}
