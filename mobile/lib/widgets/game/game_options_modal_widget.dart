import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/services/auth_service.dart';

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
  bool _hasEntryFeeError = false;
  bool _hasInsufficientFunds = false;

  @override
  void initState() {
    super.initState();
    _entryFeeController.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final text = _entryFeeController.text;
    if (text.startsWith('0') && text.length > 1) {
      final newText = text.substring(1);
      _entryFeeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }

    final value = int.tryParse(text) ?? 0;
    final user = AuthService().notifier.value;
    final userMoney = user?.virtualMoney ?? 0;

    setState(() {
      _hasEntryFeeError = value > 500;
      _hasInsufficientFunds = value > userMoney && value <= 500;
    });
  }

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
    final raw = int.tryParse(_entryFeeController.text) ?? 0;
    if (raw > 500) {
      _showEntryFeeAlert();
      return;
    }

    final user = AuthService().notifier.value;
    final userMoney = user?.virtualMoney ?? 0;

    if (raw > userMoney) {
      return;
    }

    widget.onNext(
      isFastElimination: _isFastElimination,
      isDropInOut: _isDropInOut,
      isFriendsOnly: _isFriendsOnly,
      entryFee: raw,
    );
  }

  void _showEntryFeeAlert() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF2C3E50) : Colors.white;
        final borderColor = AppColors.accentHighlight(context);
        final textColor = isDark ? Colors.white : Colors.black87;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 2),
              ),
              title: Center(
                child: Text(
                  "Frais d'entrée invalide",
                  style: TextStyle(color: textColor),
                ),
              ),
              content: Text(
                'Le montant des frais d\'entrée doit être inférieur ou égal à 500 pièces.',
                style: TextStyle(color: textColor),
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: borderColor,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _canProceed() {
    final raw = int.tryParse(_entryFeeController.text) ?? 0;
    if (raw > 500) return false;

    final user = AuthService().notifier.value;
    final userMoney = user?.virtualMoney ?? 0;

    return raw <= userMoney;
  }

  @override
  void dispose() {
    _entryFeeController.removeListener(_handleTextChange);
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 800,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildOption(
                          label: 'Elimination rapide',
                          description:
                              'Les joueurs éliminés en combat passent en mode observation',
                          value: _isFastElimination,
                          onTap: _toggleFastElimination,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildEntryFeeInput()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildOption(
                          label: 'Drop In/Drop Out',
                          description:
                              'Les joueurs peuvent rejoindre ou quitter la partie à tout moment',
                          value: _isDropInOut,
                          onTap: _toggleDropInDropOut,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildOption(
                          label: 'Amis seulement',
                          description:
                              'Seuls vos amis peuvent rejoindre cette partie',
                          value: _isFriendsOnly,
                          onTap: _toggleFriendsOnly,
                        ),
                      ),
                    ],
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
                          backgroundColor:
                              _canProceed() ? borderColor : Colors.grey,
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
      ),
    );
  }

  Widget _buildEntryFeeInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppColors.accentHighlight(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;
    final checkboxBorderColor = isDark ? Colors.white24 : Colors.black26;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: checkboxBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _entryFeeController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: textColor, fontSize: 16),
            onTap: () {
              if (_entryFeeController.text == '0') {
                _entryFeeController.clear();
              }
            },
            onTapOutside: (_) {
              if (_entryFeeController.text.isEmpty) {
                _entryFeeController.text = '0';
                setState(() => _hasEntryFeeError = false);
              }
            },
            onEditingComplete: () {
              if (_entryFeeController.text.isEmpty) {
                _entryFeeController.text = '0';
                setState(() => _hasEntryFeeError = false);
              }
              FocusScope.of(context).unfocus();
            },
            decoration: InputDecoration(
              suffixText: 'pièces',
              suffixStyle: TextStyle(color: textColorSecondary),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              errorText: _hasEntryFeeError ? 'Maximum 500 pièces' : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color:
                      _hasEntryFeeError || _hasInsufficientFunds
                          ? Colors.red
                          : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color:
                      _hasEntryFeeError || _hasInsufficientFunds
                          ? Colors.red
                          : borderColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
          if (_hasInsufficientFunds)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Vous n\'avez pas assez de monnaie virtuelle pour payer ces frais d\'entrée',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Montant que chaque joueur doit payer pour rejoindre',
            style: TextStyle(color: textColorSecondary, fontSize: 12),
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
        height: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? borderColor : checkboxBorderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
