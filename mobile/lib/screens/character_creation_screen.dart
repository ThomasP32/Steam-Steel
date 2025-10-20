import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/character_creation_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({required this.gameId, super.key});
  final String gameId;

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  String name = '';
  Specs _specs = Specs(
    life: DEFAULT_HP,
    speed: DEFAULT_SPEED,
    attack: DEFAULT_ATTACK,
    defense: DEFAULT_DEFENSE,
    attackBonus: Bonus.d4,
    defenseBonus: Bonus.d4,
  );
  String? lifeOrSpeedBonus;
  String? attackOrDefenseBonus;
  bool _isSubmitting = false;

  String _diceAsset(Bonus bonus) => 'lib/assets/icons/d${bonus.value}.png';
  final CharacterCreationService _creationService = CharacterCreationService();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    if (widget.gameId.isNotEmpty) {
      _creationService.startListening(widget.gameId);
    }
  }

  Future<void> _loadUserName() async {
    final user = AuthService().notifier.value;
    if (user != null && user.username.isNotEmpty) {
      setState(() {
        name = user.username;
      });
    }
  }

  void _addBonus(String type) {
    setState(() {
      _specs = _creationService.assignBonus(_specs, type);
      lifeOrSpeedBonus = type;
    });
  }

  void _assignDice(String which) {
    setState(() {
      _specs = _creationService.assignDice(_specs, which);
      attackOrDefenseBonus = which;
    });
  }

  void _onSubmit() {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    _creationService.joinGame(
      gameId: widget.gameId,
      name: name,
      socketId: SocketService().socketId ?? '',
      avatar: _creationService.selectedAvatar.value,
      specs: _specs,
      onSuccess: (player) {
        if (!mounted) return;
        PlayerService().setPlayer(player);
        setState(() {
          _isSubmitting = false;
        });
        GoRouter.of(context).go('/${widget.gameId}/waiting-room/player');
      },
      onTimeout: () {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _creationService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        lifeOrSpeedBonus != null &&
        attackOrDefenseBonus != null &&
        !_isSubmitting;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/backgrounds/backgroundcombat.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(flex: 3, child: _buildStatsPanel()),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _buildCenterPanel(canSubmit)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _buildAvatarGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () {
            if (mounted) context.go('/');
          },
          child: const Text('Retour'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Stats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _statRow('Vie', _specs.life, Colors.orange),
        _statRow('Rapidité', _specs.speed, Colors.orange),
        _statRow('Attaque', _specs.attack, Colors.orange),
        _statRow('Défense', _specs.defense, Colors.orange),
        const SizedBox(height: 12),
        const Text('Ajoutes un bonus:'),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => _addBonus('life'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    lifeOrSpeedBonus == 'life' ? Colors.orange : null,
              ),
              child: const Text('Vie'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _addBonus('speed'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    lifeOrSpeedBonus == 'speed' ? Colors.orange : null,
              ),
              child: const Text('Rapidité'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Attribues un dé à 6 faces:'),
        Row(
          children: [
            _buildDiceColumn('attack', _specs.attackBonus),
            const SizedBox(width: 8),
            _buildDiceColumn('defense', _specs.defenseBonus),
          ],
        ),
      ],
    );
  }

  Widget _buildDiceColumn(String type, Bonus bonus) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () => _assignDice(type),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                attackOrDefenseBonus == type ? Colors.orange : null,
          ),
          child: Text(type == 'attack' ? 'Attaque' : 'Défense'),
        ),
        const SizedBox(height: 6),
        Image.asset(
          _diceAsset(bonus),
          width: 48,
          height: 48,
          fit: BoxFit.contain,
          errorBuilder:
              (_, __, ___) =>
                  const Text('d4', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildCenterPanel(bool canSubmit) {
    return ValueListenableBuilder<int>(
      valueListenable: _creationService.selectedAvatar,
      builder: (context, avatar, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CHOISIS TON AVATAR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 400,
              height: 500,
              child: Center(
                child: Image.asset(
                  'lib/assets/characters/$avatar.png',
                  width: 350,
                  height: 350,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (ctx, err, stack) => Image.asset(
                        'lib/assets/characters/unlocked.png',
                        width: 120,
                        height: 120,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name.isEmpty ? 'Aucun nom' : name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: canSubmit ? _onSubmit : null,
              child: Text(
                widget.gameId.isEmpty
                    ? 'Créer une partie'
                    : 'Rejoindre la partie',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarGrid() {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: _creationService.unavailableAvatars,
      builder: (context, unavailable, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _creationService.selectedAvatar,
          builder: (context, selected, _) {
            return GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              children: List.generate(12, (index) {
                final id = index + 1;
                final isAvailable = !unavailable.contains(id);
                return GestureDetector(
                  onTap:
                      isAvailable
                          ? () => _creationService.selectAvatar(id)
                          : null,
                  child: Opacity(
                    opacity: isAvailable ? 1.0 : 0.4,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color:
                            id == selected ? Colors.orange : Colors.grey[800],
                        border: Border.all(color: Colors.orange, width: 3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'lib/assets/previewcharacters/${id}_preview.png',
                          fit: BoxFit.contain,
                          errorBuilder:
                              (ctx, err, stack) => Image.asset(
                                'lib/assets/characters/unlocked.png',
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _statRow(String label, int value, Color color) {
    final pct = (value / 10).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : $value'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct,
            color: color,
            backgroundColor: Colors.grey.shade700,
            minHeight: 15,
          ),
        ],
      ),
    );
  }
}
