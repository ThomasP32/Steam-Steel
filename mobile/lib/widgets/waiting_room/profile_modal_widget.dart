import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';

class ProfileModalWidget extends StatefulWidget {
  const ProfileModalWidget({
    required this.activePlayers,
    required this.onSubmit,
    super.key,
  });

  final List<Player> activePlayers;
  final void Function(Player virtualPlayer) onSubmit;

  @override
  State<ProfileModalWidget> createState() => _ProfileModalWidgetState();
}

class _ProfileModalWidgetState extends State<ProfileModalWidget> {
  ProfileType? _selectedProfile;
  final _random = Random();

  Player _createVirtualPlayer() {
    final usedNames = widget.activePlayers.map((p) => p.name).toList();
    final availableNames =
        BotName.values
            .map((e) => e.displayName)
            .where((name) => !usedNames.contains(name))
            .toList();
    final randomName =
        availableNames.isNotEmpty
            ? availableNames[_random.nextInt(availableNames.length)]
            : 'Bot${DateTime.now().millisecond}';

    final usedAvatars = widget.activePlayers.map((p) => p.avatar).toList();
    final availableAvatars =
        Avatar.values.where((a) => !usedAvatars.contains(a)).toList();
    final randomAvatar =
        availableAvatars.isNotEmpty
            ? availableAvatars[_random.nextInt(availableAvatars.length)]
            : Avatar.avatar1;

    final lifeBonus = _random.nextDouble() < HALF;
    final attackBonus = _random.nextDouble() < HALF;

    final specs = Specs(
      life: lifeBonus ? DEFAULT_HP + BONUS : DEFAULT_HP,
      speed: lifeBonus ? DEFAULT_SPEED : DEFAULT_SPEED + BONUS,
      attack: DEFAULT_ATTACK,
      defense: DEFAULT_DEFENSE,
      attackBonus: attackBonus ? Bonus.d6 : Bonus.d4,
      defenseBonus: attackBonus ? Bonus.d4 : Bonus.d6,
      evasions: DEFAULT_EVASIONS,
      actions: DEFAULT_ACTIONS,
    );

    return Player(
      name: randomName,
      socketId: 'virtualPlayer${DateTime.now().millisecondsSinceEpoch}',
      avatar: randomAvatar,
      specs: specs,
      profile: _selectedProfile ?? ProfileType.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir le profil du joueur virtuel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ProfileButton(
                  label: 'Agressif',
                  isSelected: _selectedProfile == ProfileType.aggressive,
                  onTap:
                      () => setState(
                        () => _selectedProfile = ProfileType.aggressive,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileButton(
                  label: 'Défensif',
                  isSelected: _selectedProfile == ProfileType.defensive,
                  onTap:
                      () => setState(
                        () => _selectedProfile = ProfileType.defensive,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed:
              _selectedProfile == null
                  ? null
                  : () {
                    final virtualPlayer = _createVirtualPlayer();
                    widget.onSubmit(virtualPlayer);
                    Navigator.of(context).pop();
                  },
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected ? AppColors.accentHighlight(context) : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color:
              isSelected
                  ? AppColors.accentHighlight(context).withValues(alpha: 0.1)
                  : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color:
                isSelected ? AppColors.accentHighlight(context) : Colors.white,
          ),
        ),
      ),
    );
  }
}
