import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/widgets/friends/friend_list_modal.dart';

class FriendButton extends StatelessWidget {
  const FriendButton({super.key, this.withPadding = true});

  final bool withPadding;

  void _showFriendList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FriendListModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark
            ? AppColors.buttonBackgroundDark
            : AppColors.buttonBackgroundLight;
    final iconColor =
        isDark ? AppColors.buttonTextDark : AppColors.buttonTextLight;

    final button = SizedBox(
      width: 44,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _showFriendList(context),
        child: Icon(Icons.people, color: iconColor, size: 24),
      ),
    );

    if (!withPadding) {
      return button;
    }

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 18, right: 12),
        child: button,
      ),
    );
  }
}
