import 'dart:async';

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
  bool isEditing = false;
  int life = 4;
  int speed = 4;
  int attack = 4;
  int defense = 4;
  String? lifeOrSpeedBonus;
  String? attackOrDefenseBonus;
  int? attackBonus;
  int? defenseBonus;
  int selectedAvatar = 1;
  bool _isSubmitting = false;
  String _diceAsset(int? faces) => 'lib/assets/icons/d${faces ?? 4}.png';
  StreamSubscription<dynamic>? _youJoinedSub;
  final CharacterCreationService _creationService = CharacterCreationService();

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = AuthService().notifier.value;
    if (user != null && user.username.isNotEmpty) {
      setState(() {
        name = user.username;
      });
    }
  }

  void toggleEditing() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  void addBonus(String b) {
    final specs = Specs(
      life: life,
      speed: speed,
      attack: attack,
      defense: defense,
      attackBonus: (attackBonus == 6) ? Bonus.d6 : Bonus.d4,
      defenseBonus: (defenseBonus == 6) ? Bonus.d6 : Bonus.d4,
    );
    final updated = _creationService.assignBonus(specs, b);
    setState(() {
      life = updated.life;
      speed = updated.speed;
      lifeOrSpeedBonus = b;
    });
  }

  void assignDice(String which) {
    final specs = Specs(
      life: life,
      speed: speed,
      attack: attack,
      defense: defense,
      attackBonus: (attackBonus == 6) ? Bonus.d6 : Bonus.d4,
      defenseBonus: (defenseBonus == 6) ? Bonus.d6 : Bonus.d4,
    );
    final updated = _creationService.assignDice(specs, which);
    setState(() {
      attackBonus = updated.attackBonus.value;
      defenseBonus = updated.defenseBonus.value;
      attackOrDefenseBonus = which;
    });
  }

  void onSubmit() {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    final player = {
      'name': name,
      'socketId': SocketService().socketId ?? '',
      'isActive': true,
      'avatar': selectedAvatar,
      'specs': {
        'life': life,
        'speed': speed,
        'attack': attack,
        'defense': defense,
        'attackBonus': attackBonus ?? Bonus.d4.value,
        'defenseBonus': defenseBonus ?? Bonus.d6.value,
        'movePoints': speed,
        'evasions': DEFAULT_EVASIONS,
        'actions': DEFAULT_ACTIONS,
        'nVictories': 0,
        'nDefeats': 0,
        'nCombats': 0,
        'nEvasions': 0,
        'nLifeTaken': 0,
        'nLifeLost': 0,
        'nItemsUsed': 0,
      },
      'inventory': <dynamic>[],
      'position': {'x': 0, 'y': 0},
      'initialPosition': {'x': 0, 'y': 0},
      'turn': 0,
      'visitedTiles': <dynamic>[],
      'profile': ProfileType.normal.value,
    };

    final localPlayer = Player(
      socketId: player['socketId']! as String,
      name: player['name']! as String,
      avatar:
          Avatar.values[((player['avatar']! as int) - 1).clamp(
            0,
            Avatar.values.length - 1,
          )],
      specs: Specs(
        life: (player['specs']! as Map)['life'] as int,
        speed: (player['specs']! as Map)['speed'] as int,
        attack: (player['specs']! as Map)['attack'] as int,
        defense: (player['specs']! as Map)['defense'] as int,
        attackBonus:
            (player['specs']! as Map)['attackBonus'] == 6 ? Bonus.d6 : Bonus.d4,
        defenseBonus:
            (player['specs']! as Map)['defenseBonus'] == 6
                ? Bonus.d6
                : Bonus.d4,
        movePoints: (player['specs']! as Map)['movePoints'] as int,
        evasions: (player['specs']! as Map)['evasions'] as int,
        actions: (player['specs']! as Map)['actions'] as int,
      ),
    );

    final payload = {'gameId': widget.gameId, 'player': player};

    _listenToYouJoined(localPlayer);
    SocketService().send('joinGame', payload);
    _setupJoinTimeout();
  }

  void _listenToYouJoined(Player localPlayer) {
    _youJoinedSub?.cancel();
    _youJoinedSub = SocketService().listen<dynamic>('youJoined').listen((data) {
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        PlayerService().setPlayerFromJson(data);
      } else {
        PlayerService().setPlayer(localPlayer);
      }
      _youJoinedSub?.cancel();
      setState(() {
        _isSubmitting = false;
      });
      GoRouter.of(context).go('/${widget.gameId}/waiting-room/player');
    });
  }

  void _setupJoinTimeout() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        _youJoinedSub?.cancel();
        setState(() {
          _isSubmitting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _youJoinedSub?.cancel();
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
              // Left: stats and bonuses
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (mounted) context.go('/');
                      },
                      child: const Text('Retour'),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Stats',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _statRow('Vie', life, Colors.orange),
                    _statRow('Rapidité', speed, Colors.orange),
                    _statRow('Attaque', attack, Colors.orange),
                    _statRow('Défense', defense, Colors.orange),
                    const SizedBox(height: 12),
                    const Text('Ajoutes un bonus:'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: () => addBonus('life'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                lifeOrSpeedBonus == 'life'
                                    ? Colors.orange
                                    : null,
                          ),
                          child: const Text('Vie'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => addBonus('speed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                lifeOrSpeedBonus == 'speed'
                                    ? Colors.orange
                                    : null,
                          ),
                          child: const Text('Rapidité'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Attribues un dé à 6 faces:'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => assignDice('attack'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    attackOrDefenseBonus == 'attack'
                                        ? Colors.orange
                                        : null,
                              ),
                              child: const Text('Attaque'),
                            ),
                            const SizedBox(height: 6),
                            Image.asset(
                              _diceAsset(attackBonus),
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, __, ___) => const Text(
                                    'd4',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => assignDice('defense'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    attackOrDefenseBonus == 'defense'
                                        ? Colors.orange
                                        : null,
                              ),
                              child: const Text('Défense'),
                            ),
                            const SizedBox(height: 6),
                            Image.asset(
                              _diceAsset(defenseBonus),
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, __, ___) => const Text(
                                    'd4',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Center: avatar + name + submit
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CHOISIS TON AVATAR',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 400,
                      height: 500,
                      child: Center(
                        child: Image.asset(
                          'lib/assets/characters/$selectedAvatar.png',
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: canSubmit ? onSubmit : null,
                      child: Text(
                        widget.gameId.isEmpty
                            ? 'Créer une partie'
                            : 'Rejoindre la partie',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right: list of avatars
              Expanded(
                flex: 3,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  children: List.generate(12, (index) {
                    final id = index + 1;
                    return GestureDetector(
                      onTap: () => setState(() => selectedAvatar = id),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color:
                              id == selectedAvatar
                                  ? Colors.orange
                                  : Colors.grey[800],
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
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
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
