import 'package:flutter/material.dart';

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
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              border: Border.all(color: Colors.orange, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Options de jeu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Carte: ${widget.selectedMapName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
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
                      child: const Text(
                        'Retour',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Suivant',
                        style: TextStyle(fontSize: 16),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
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
                        return const Icon(
                          Icons.monetization_on,
                          size: 20,
                          color: Color(0xFF7D4F00),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Frais d'entrée",
                      style: TextStyle(
                        color: Colors.orange,
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
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      suffixText: 'pièces',
                      suffixStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.orange,
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
                const Text(
                  'Montant que chaque joueur doit payer pour rejoindre la partie. Les gains seront redistribués aux gagnants.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? Colors.orange : Colors.white24),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (_) => onTap(),
              activeColor: Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
