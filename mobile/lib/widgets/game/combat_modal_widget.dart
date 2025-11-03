import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';

class CombatModalWidget extends StatefulWidget {
  const CombatModalWidget({
    required this.challenger,
    required this.opponent,
    required this.gameId,
    super.key,
  });

  final Map<String, dynamic> challenger;
  final Map<String, dynamic> opponent;
  final String gameId;

  @override
  State<CombatModalWidget> createState() => _CombatModalWidgetState();
}

class _CombatModalWidgetState extends State<CombatModalWidget> {
  bool _isYourTurn = false;
  int _countdown = 5;
  String _combatMessage = '';
  int? _attackDice;
  int? _defenseDice;
  bool _attacking = false;
  Map<String, dynamic>? _currentChallenger;
  Map<String, dynamic>? _currentOpponent;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _currentChallenger = Map<String, dynamic>.from(widget.challenger);
    _currentOpponent = Map<String, dynamic>.from(widget.opponent);

    final currentPlayer = PlayerService().player;
    final challengerSocketId = _currentChallenger?['socketId'] as String?;
    _isYourTurn = currentPlayer.socketId == challengerSocketId;

    if (_isYourTurn) {
      _combatMessage = "C'est à votre tour de jouer!";
    } else {
      final opponentName = _currentOpponent?['name'] as String? ?? 'Adversaire';
      _combatMessage = '$opponentName est en train de jouer.';
    }

    _listenToCombatEvents();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listenToCombatEvents() {
    _subscriptions
      ..add(
        SocketService().listen<dynamic>('yourTurnCombat').listen((_) {
          if (!mounted) return;
          setState(() {
            _isYourTurn = true;
            _combatMessage = "C'est à votre tour de jouer!";
          });
        }),
      )
      ..add(
        SocketService().listen<dynamic>('playerTurnCombat').listen((_) {
          if (!mounted) return;
          setState(() {
            _isYourTurn = false;
            final opponentName =
                _currentOpponent?['name'] as String? ?? 'Adversaire';
            _combatMessage = '$opponentName est en train de jouer.';
          });
        }),
      )
      ..add(
        SocketService().listen<int>('combatSecondPassed').listen((time) {
          if (!mounted) return;
          setState(() {
            _countdown = time;
          });
        }),
      )
      ..add(
        SocketService().listen<dynamic>('diceRolled').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final attackDice = data['attackDice'] as int?;
            final defenseDice = data['defenseDice'] as int?;

            setState(() {
              if (_isYourTurn) {
                _attackDice = attackDice;
                _defenseDice = defenseDice;
                _attacking = true;
              } else {
                _attackDice = defenseDice;
                _defenseDice = attackDice;
                _attacking = false;
              }
            });
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('attackSuccess').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final playerSocketId = data['socketId'] as String?;
            final playerName = data['name'] as String?;

            setState(() {
              if (playerSocketId == _currentOpponent?['socketId']) {
                _currentOpponent = data;
                _combatMessage = 'Vous avez attaqué $playerName';
              } else if (playerSocketId == _currentChallenger?['socketId']) {
                _currentChallenger = data;
                final opponentName =
                    _currentOpponent?['name'] as String? ?? 'Adversaire';
                _combatMessage = '$opponentName vous a attaqué';
              }
            });
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('attackFailure').listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            final playerSocketId = data['socketId'] as String?;
            final playerName = data['name'] as String?;

            setState(() {
              if (playerSocketId == _currentOpponent?['socketId']) {
                _combatMessage = '$playerName a survécu à votre attaque';
              } else {
                _combatMessage = 'Vous avez survécu à une attaque';
              }
            });
          }
        }),
      );
  }

  void _attack() {
    if (_isYourTurn) {
      SocketService().send('attack', widget.gameId);
      setState(() {
        _isYourTurn = false;
      });
    }
  }

  void _evade() {
    if (_isYourTurn) {
      SocketService().send('startEvasion', widget.gameId);
      setState(() {
        _isYourTurn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Player>(
      valueListenable: PlayerService().notifier,
      builder: (context, currentPlayer, _) {
        final isMyTurn = _isYourTurn;
        final evasionsLeft = currentPlayer.specs.evasions;

        return ColoredBox(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCombatPlayer(_currentChallenger!, true),
                      Column(
                        children: [
                          if (_attackDice != null || _defenseDice != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (_attackDice != null)
                                  _buildDice(_attackDice!, _attacking),
                                const SizedBox(width: 20),
                                if (_defenseDice != null)
                                  _buildDice(_defenseDice!, !_attacking),
                              ],
                            ),
                          ],
                        ],
                      ),
                      _buildCombatPlayer(_currentOpponent!, false),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    _combatMessage.isEmpty
                        ? 'Le combat est en cours...'
                        : _combatMessage,
                    style: TextStyle(
                      color: isMyTurn ? Colors.greenAccent : Colors.white70,
                      fontSize: 16,
                      fontWeight:
                          isMyTurn ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: isMyTurn ? _attack : null,
                        style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'Attaquer',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed:
                            (isMyTurn && evasionsLeft > 0) ? _evade : null,
                        style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          'Évasion ($evasionsLeft)',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDice(int value, bool isAttack) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        value.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCombatPlayer(Map<String, dynamic> player, bool isLeft) {
    final name = player['name'] as String? ?? 'Joueur';

    final avatar = player['avatar'];
    final avatarValue =
        avatar is Map ? (avatar['value'] ?? '1') : (avatar ?? '1');

    final specs = player['specs'] as Map<String, dynamic>?;
    final life = specs?['life'] ?? 0;
    final attack = specs?['attack'] ?? 0;
    final defense = specs?['defense'] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(color: Color(0xFF3A4F5F)),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'lib/assets/characters/$avatarValue.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '❤️ $life',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          '⚔️ $attack',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          '🛡️ $defense',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
