import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/models/user_models.dart';
import 'package:mobile/utils/debug_logger.dart';

class ProfilePictureWidget extends StatelessWidget {
  const ProfilePictureWidget({
    required this.size,
    super.key,
    this.avatar,
    this.avatarCustom,
    this.profilePicture,
    this.profilePictureCustom,
    this.status,
    this.showStatusIndicator = true,
    this.username,
  });

  final double size;
  final int? avatar;
  final String? avatarCustom;
  final int? profilePicture;
  final String? profilePictureCustom;
  final UserStatus? status;
  final bool showStatusIndicator;
  final String? username;

  Color _getStatusColor() {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.offline:
        return Colors.grey;
      case UserStatus.inGame:
        return Colors.orange;
      case UserStatus.unknown:
      case null:
        return Colors.grey;
    }
  }

  int _getDefaultAvatar() {
    // Priority: profilePicture > avatar > default
    if (profilePicture != null) return profilePicture!;
    if (avatar != null) return avatar!;
    if (username == null || username!.isEmpty) return 1;

    final hash = username!.hashCode.abs();
    return (hash % 10) + 1;
  }

  bool _isUrl(String path) {
    return path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:');
  }

  ImageProvider _getAvatarImageProvider() {
    // If username is [supprimé], don't show any image - let parent handle icon
    if (username == '[supprimé]') {
      // Return a transparent placeholder that won't be visible
      return const AssetImage('lib/assets/profile/1.png');
    }

    // Priority: profilePictureCustom > profilePicture > avatarCustom > avatar > default
    if (profilePictureCustom != null && profilePictureCustom!.isNotEmpty) {
      if (_isUrl(profilePictureCustom!)) {
        if (profilePictureCustom!.startsWith('data:')) {
          try {
            final base64String = profilePictureCustom!.split(',')[1];
            final bytes = base64Decode(base64String);
            return MemoryImage(bytes);
          } catch (e) {
            DebugLogger.log(
              'Failed to decode base64 profile picture: $e',
              tag: 'ProfilePictureWidget',
            );
            // Fallback to avatar if profile picture fails
          }
        } else {
          return NetworkImage(profilePictureCustom!);
        }
      } else {
        return FileImage(File(profilePictureCustom!));
      }
    }

    if (profilePicture != null) {
      return AssetImage('lib/assets/profile/$profilePicture.png');
    }

    if (avatarCustom != null && avatarCustom!.isNotEmpty) {
      if (_isUrl(avatarCustom!)) {
        if (avatarCustom!.startsWith('data:')) {
          try {
            final base64String = avatarCustom!.split(',')[1];
            final bytes = base64Decode(base64String);
            return MemoryImage(bytes);
          } catch (e) {
            DebugLogger.log(
              'Failed to decode base64 avatar: $e',
              tag: 'ProfilePictureWidget',
            );
            final avatarNumber = _getDefaultAvatar();
            return AssetImage('lib/assets/characters/$avatarNumber.png');
          }
        }
        return NetworkImage(avatarCustom!);
      } else {
        return FileImage(File(avatarCustom!));
      }
    }

    final avatarNumber = _getDefaultAvatar();
    return AssetImage('lib/assets/characters/$avatarNumber.png');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final indicatorSize = size * 0.25;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              image: DecorationImage(
                image: _getAvatarImageProvider(),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (showStatusIndicator && status != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  border: Border.all(color: const Color(0xFF2C3E50), width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
