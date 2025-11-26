import 'package:flutter/material.dart';
import 'package:mobile/services/theme_service.dart';
import 'package:provider/provider.dart';

class ThemeBackground extends StatelessWidget {
  const ThemeBackground({super.key, this.pageId});

  final String? pageId;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService?>();
    if (theme == null) {
      return Container(color: Colors.black);
    }

    String? bg;
    if (pageId != null) {
      try {
        final pages = theme.themeJson?['pages'] as Map<String, dynamic>?;
        final pageObj = pages?[pageId] as Map<String, dynamic>?;
        if (pageObj != null) {
          final key =
              theme.isLight
                  ? (pageObj['light'] as String?)
                  : (pageObj['default'] as String?);
          if (key != null && key.isNotEmpty) {
            bg = 'lib/assets/backgrounds/$key.png';
          }
        }
      } catch (_) {}
    }

    if (bg == null) {
      return Container(color: Colors.black);
    }

    return Image.asset(bg, fit: BoxFit.cover);
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({
    super.key,
    this.onPressed,
    this.pageId,
    this.perPage = false,
  });
  final VoidCallback? onPressed;
  final String? pageId;
  final bool perPage;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService?>();
    return SizedBox(
      width: 44,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: EdgeInsets.zero,
        ),
        onPressed:
            onPressed ??
            () {
              if (theme == null) return;
              theme.toggle();
            },
        child: Icon(
          theme?.isLight ?? false ? Icons.dark_mode : Icons.light_mode,
          size: 24,
        ),
      ),
    );
  }
}
