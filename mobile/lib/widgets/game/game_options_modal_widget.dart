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
    required bool isFriendsOnly,
  })
  onNext;

  @override
  State<GameOptionsModalWidget> createState() => _GameOptionsModalWidgetState();
}

class _GameOptionsModalWidgetState extends State<GameOptionsModalWidget> {
  bool _isFastElimination = false;
  bool _isFriendsOnly = false;

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

  void _handleNext() {
    widget.onNext(
      isFastElimination: _isFastElimination,
      isFriendsOnly: _isFriendsOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
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
              _buildOption(
                label: "Mode d'élimination rapide",
                description:
                    'Les joueurs éliminés en combat passent en mode observation',
                value: _isFastElimination,
                onTap: _toggleFastElimination,
              ),
              const SizedBox(height: 16),
              _buildOption(
                label: 'Partie amis seulement',
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
