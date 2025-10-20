import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/common/game.dart';

typedef AvatarChanged = void Function(Avatar avatar);
typedef CustomAvatarChanged = void Function(String? path);

class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    required this.selected,
    required this.onAvatarChanged,
    required this.onCustomPreviewChanged,
    super.key,
    this.customPreview,
  });

  final Avatar selected;
  final String? customPreview;
  final AvatarChanged onAvatarChanged;
  final CustomAvatarChanged onCustomPreviewChanged;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  Future<void> _pickCustomAvatar() async {
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
    const avatars = Avatar.values;
    final hasCustom =
        widget.customPreview != null && widget.customPreview!.isNotEmpty;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in avatars)
          GestureDetector(
            onTap: () {
              widget.onCustomPreviewChanged(null);
              widget.onAvatarChanged(a);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      widget.selected == a && !hasCustom
                          ? Colors.blueAccent
                          : Colors.transparent,
                  width: 3,
                ),
                boxShadow:
                    widget.selected == a && !hasCustom
                        ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.16),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                        : null,
                image: DecorationImage(
                  image: AssetImage('lib/assets/characters/${a.value}.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        GestureDetector(
          onTap: _pickCustomAvatar,
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
          (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey.shade500),
    );
  }
}
