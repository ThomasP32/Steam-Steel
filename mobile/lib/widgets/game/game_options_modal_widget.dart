import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';

class GameOptionsModalWidget extends StatefulWidget {
  const GameOptionsModalWidget({
    required this.selectedMapName,
    required this.onClose,
    required this.onNext,
    super.key,
  });

  final String selectedMapName;
  final VoidCallback onClose;
  final void Function({
    required bool isFastElimination,
    required bool isDropInOut,
    required bool isFriendsOnly,
    required int entryFee,
  })
  onNext;

  @override
  State<GameOptionsModalWidget> createState() => _GameOptionsModalWidgetState();
}

class _GameOptionsModalWidgetState extends State<GameOptionsModalWidget> {
  bool _isFastElimination = false;
  bool _isDropInOut = false;
  bool _isFriendsOnly = false;
  final TextEditingController _entryFeeController = TextEditingController(
    text: '0',
  );

  void _toggleFastElimination() {
    setState(() {
      _isFastElimination = !_isFastElimination;
    });
  }

  void _toggleFriendsOnly() {
    setState(() {
      _isFriendsOnly = !_isFriendsOnly;
    });
  }

  void _toggleDropInDropOut() {
    setState(() {
      _isDropInOut = !_isDropInOut;
    });
  }

  void _handleNext() {
    final entryFee = int.tryParse(_entryFeeController.text) ?? 0;
    widget.onNext(
      isFastElimination: _isFastElimination,
      isDropInOut: _isDropInOut,
      isFriendsOnly: _isFriendsOnly,
      entryFee: entryFee,
    );
  }

  @override
  void dispose() {
    _entryFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C3E50) : Colors.white;
    final borderColor = AppColors.accentHighlight(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Options de jeu',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Carte: ${widget.selectedMapName}',
                  style: TextStyle(color: textColorSecondary, fontSize: 16),
                ),
                const SizedBox(height: 24),
                _buildEntryFeeInput(),
                const SizedBox(height: 16),
                _buildOption(
                  label: 'Elimination rapide',
                  description:
                      'Les joueurs éliminés en combat passent en mode observation',
                  value: _isFastElimination,
                  onTap: _toggleFastElimination,
                ),
                const SizedBox(height: 16),
                _buildOption(
                  label: 'Drop In/Drop Out',
                  description:
                      'Les joueurs peuvent rejoindre ou quitter la partie à tout moment',
                  value: _isDropInOut,
                  onTap: _toggleDropInDropOut,
                ),
                const SizedBox(height: 16),
                _buildOption(
                  label: 'Amis seulement',
                  description: 'Seuls vos amis peuvent rejoindre cette partie',
                  value: _isFriendsOnly,
                  onTap: _toggleFriendsOnly,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: widget.onClose,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Retour',
                        style: TextStyle(
                          color: textColorSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: borderColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Suivant',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryFeeInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppColors.accentHighlight(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'lib/assets/icons/money.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.monetization_on,
                          size: 20,
                          color: borderColor,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Frais d'entrée",
                      style: TextStyle(
                        color: borderColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _entryFeeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      suffixText: 'pièces',
                      suffixStyle: TextStyle(color: textColorSecondary),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: borderColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Montant que chaque joueur doit payer pour rejoindre la partie. Les gains seront redistribués aux gagnants.',
                  style: TextStyle(color: textColorSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String label,
    required String description,
    required bool value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppColors.accentHighlight(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final checkboxBorderColor = isDark ? Colors.white24 : Colors.black26;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? borderColor : checkboxBorderColor),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (_) => onTap(),
              activeColor: borderColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: textColorSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
