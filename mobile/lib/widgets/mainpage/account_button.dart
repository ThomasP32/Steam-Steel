import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/color_palette.dart';

class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

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
        onPressed: () => context.go('/auth'),
        child: Icon(Icons.account_circle, color: iconColor, size: 24),
      ),
    );
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 18, right: 12),
        child: button,
      ),
    );
  }
}
