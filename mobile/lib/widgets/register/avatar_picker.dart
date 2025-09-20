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
  String? _localPreview;

  @override
  void initState() {
    super.initState();
    _localPreview = widget.customPreview;
  }

  Future<void> _pickCustomAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;
    setState(() {
      _localPreview = picked.path;
    });
    widget.onCustomPreviewChanged(_localPreview);
  }

  @override
  Widget build(BuildContext context) {
    const avatars = Avatar.values;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in avatars)
          GestureDetector(
            onTap: () {
              setState(() => _localPreview = null);
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
                      widget.selected == a && _localPreview == null
                          ? Colors.blueAccent
                          : Colors.transparent,
                  width: 3,
                ),
                boxShadow:
                    widget.selected == a && _localPreview == null
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
        // upload tile
        GestureDetector(
          onTap: _pickCustomAvatar,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade600, width: 2),
              color: Colors.white,
            ),
            child:
                _localPreview == null
                    ? Center(
                      child: Icon(Icons.add, color: Colors.grey.shade500),
                    )
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_localPreview!),
                        fit: BoxFit.cover,
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}
