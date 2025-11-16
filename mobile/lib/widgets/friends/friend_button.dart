import 'package:flutter/material.dart';
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
    final button = SizedBox(
      width: 44,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C3E50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _showFriendList(context),
        child: const Icon(Icons.people, color: Color(0xFFC0C0C0), size: 24),
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
